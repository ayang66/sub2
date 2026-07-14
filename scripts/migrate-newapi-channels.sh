#!/usr/bin/env bash

set -euo pipefail

NEWAPI_DIR="${NEWAPI_DIR:-/home/ubuntu/new-api}"
SUB2_DIR="${SUB2_DIR:-/home/ubuntu/sub2api-deploy}"
NEWAPI_DB_CONTAINER="${NEWAPI_DB_CONTAINER:-new-api-postgres}"
SUB2_DB_CONTAINER="${SUB2_DB_CONTAINER:-sub2api-postgres}"
SUB2_APP_CONTAINER="${SUB2_APP_CONTAINER:-sub2api}"
SUB2_DB_USER="${SUB2_DB_USER:-sub2api}"
SUB2_DB_NAME="${SUB2_DB_NAME:-sub2api}"
OPENAI_GROUP_ID="${OPENAI_GROUP_ID:-2}"
ANTHROPIC_GROUP_ID="${ANTHROPIC_GROUP_ID:-1}"
GEMINI_GROUP_NAME="${GEMINI_GROUP_NAME:-NewAPI Gemini}"

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="${SUB2_DIR}/backups"
work_dir="$(mktemp -d)"
channels_csv="${work_dir}/newapi-channels.csv"
backup_file="${backup_dir}/sub2api-before-newapi-channel-migration-${timestamp}.dump"
gemini_group_sql="${GEMINI_GROUP_NAME//\'/\'\'}"

cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

umask 077
mkdir -p "${backup_dir}"
chmod 700 "${backup_dir}"

set -a
# shellcheck disable=SC1091
source "${NEWAPI_DIR}/.env"
set +a

new_psql=(
  docker exec -e "PGPASSWORD=${POSTGRES_PASSWORD}"
  "${NEWAPI_DB_CONTAINER}"
  psql -X -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
)
sub_psql=(
  docker exec
  "${SUB2_DB_CONTAINER}"
  psql -X -v ON_ERROR_STOP=1 -U "${SUB2_DB_USER}" -d "${SUB2_DB_NAME}"
)

for group_spec in "${OPENAI_GROUP_ID}:openai" "${ANTHROPIC_GROUP_ID}:anthropic"; do
  group_id="${group_spec%%:*}"
  expected_platform="${group_spec##*:}"
  actual_platform="$(${sub_psql[@]} -Atc "SELECT platform FROM groups WHERE id=${group_id} AND deleted_at IS NULL AND status='active'")"
  if [[ "${actual_platform}" != "${expected_platform}" ]]; then
    echo "Group ${group_id} must be an active ${expected_platform} group." >&2
    exit 1
  fi
done

docker exec "${SUB2_DB_CONTAINER}" pg_dump \
  -U "${SUB2_DB_USER}" \
  -d "${SUB2_DB_NAME}" \
  --format=custom \
  --file=/tmp/sub2api-before-newapi-channel-migration.dump
docker cp "${SUB2_DB_CONTAINER}:/tmp/sub2api-before-newapi-channel-migration.dump" "${backup_file}"
docker exec "${SUB2_DB_CONTAINER}" rm -f /tmp/sub2api-before-newapi-channel-migration.dump

"${new_psql[@]}" -Atc "COPY (
  WITH source AS (
    SELECT
      c.*,
      max(priority) OVER () AS max_priority,
      CASE c.type
        WHEN 1 THEN 'openai'
        WHEN 14 THEN 'anthropic'
        WHEN 24 THEN 'gemini'
      END AS platform
    FROM channels c
    WHERE c.type IN (1, 14, 24)
  )
  SELECT
    id,
    left('NewAPI #' || id::text || ' - ' || name, 100),
    platform,
    'apikey',
    jsonb_build_object(
      'api_key', key,
      'base_url', regexp_replace(coalesce(base_url, ''), '/+$', ''),
      'model_mapping', coalesce(
        CASE
          WHEN coalesce(trim(model_mapping), '') <> '' THEN model_mapping::jsonb
        END,
        (
          SELECT coalesce(jsonb_object_agg(model_name, model_name), '{}'::jsonb)
          FROM (
            SELECT trim(value) AS model_name
            FROM unnest(string_to_array(coalesce(models, ''), ',')) AS value
            WHERE trim(value) <> ''
          ) model_names
        )
      )
    ),
    CASE
      WHEN platform = 'openai' THEN jsonb_build_object(
        'openai_responses_mode', 'force_responses',
        'openai_responses_supported', true
      )
      ELSE '{}'::jsonb
    END,
    3,
    ((max_priority - priority) * 10 + 10)::integer,
    CASE WHEN status = 1 THEN 'active' ELSE 'disabled' END,
    status = 1,
    to_timestamp(coalesce(nullif(created_time, 0), extract(epoch FROM now())::bigint)),
    'Migrated from NewAPI channel #' || id::text ||
      '; original group=' || coalesce(\"group\", '') ||
      '; original type=' || type::text ||
      '; original priority=' || priority::text ||
      '; original models=' || coalesce(models, '')
  FROM source
  ORDER BY id
) TO STDOUT WITH (FORMAT CSV)" >"${channels_csv}"

"${sub_psql[@]}" -c "
  DROP TABLE IF EXISTS migration_newapi_channels;
  CREATE TABLE migration_newapi_channels (
    old_id bigint PRIMARY KEY,
    name text NOT NULL,
    platform text NOT NULL,
    type text NOT NULL,
    credentials jsonb NOT NULL,
    extra jsonb NOT NULL,
    concurrency integer NOT NULL,
    priority integer NOT NULL,
    status text NOT NULL,
    schedulable boolean NOT NULL,
    created_at timestamptz NOT NULL,
    notes text NOT NULL
  );
"

docker exec -i "${SUB2_DB_CONTAINER}" psql -X -v ON_ERROR_STOP=1 \
  -U "${SUB2_DB_USER}" -d "${SUB2_DB_NAME}" \
  -c "COPY migration_newapi_channels FROM STDIN WITH (FORMAT CSV)" <"${channels_csv}"

"${sub_psql[@]}" -c "
BEGIN;

INSERT INTO groups (
  name, description, rate_multiplier, is_exclusive, status,
  platform, subscription_type, default_validity_days,
  supported_model_scopes, allow_image_generation
)
SELECT
  '${gemini_group_sql}', 'Gemini accounts migrated from NewAPI', 1, false, 'active',
  'gemini', 'standard', 30, '[\"gemini_text\",\"gemini_image\"]'::jsonb, true
WHERE NOT EXISTS (
  SELECT 1 FROM groups
  WHERE deleted_at IS NULL AND name = '${gemini_group_sql}'
);

UPDATE groups
SET allow_image_generation = true, updated_at = now()
WHERE id = ${OPENAI_GROUP_ID};

INSERT INTO accounts (
  name, platform, type, credentials, extra, concurrency, priority,
  status, schedulable, created_at, updated_at, notes,
  auto_pause_on_expired, rate_multiplier, quota_dimension
)
SELECT
  s.name, s.platform, s.type, s.credentials, s.extra, s.concurrency,
  s.priority, s.status, s.schedulable, s.created_at, now(), s.notes,
  true, 1, 'global'
FROM migration_newapi_channels s
WHERE NOT EXISTS (
  SELECT 1 FROM accounts a
  WHERE a.deleted_at IS NULL
    AND a.notes LIKE 'Migrated from NewAPI channel #' || s.old_id::text || ';%'
);

CREATE TEMP TABLE migration_newapi_account_map ON COMMIT DROP AS
SELECT
  s.old_id,
  a.id AS account_id,
  s.platform,
  s.priority,
  CASE s.platform
    WHEN 'openai' THEN ${OPENAI_GROUP_ID}
    WHEN 'anthropic' THEN ${ANTHROPIC_GROUP_ID}
    WHEN 'gemini' THEN (
      SELECT id FROM groups
      WHERE deleted_at IS NULL AND name = '${gemini_group_sql}'
      ORDER BY id LIMIT 1
    )
  END AS group_id
FROM migration_newapi_channels s
JOIN accounts a
  ON a.deleted_at IS NULL
 AND a.notes LIKE 'Migrated from NewAPI channel #' || s.old_id::text || ';%';

INSERT INTO account_groups (account_id, group_id, priority, created_at)
SELECT account_id, group_id, priority, now()
FROM migration_newapi_account_map
WHERE group_id IS NOT NULL
ON CONFLICT (account_id, group_id)
DO UPDATE SET priority = EXCLUDED.priority;

COMMIT;
"

"${sub_psql[@]}" -P pager=off -c "
  SELECT platform, status, count(*) AS accounts
  FROM accounts
  WHERE deleted_at IS NULL
    AND notes LIKE 'Migrated from NewAPI channel #%'
  GROUP BY platform, status
  ORDER BY platform, status;
"

"${sub_psql[@]}" -c "DROP TABLE migration_newapi_channels;"

docker restart "${SUB2_APP_CONTAINER}" >/dev/null

echo "Backup: ${backup_file}"
