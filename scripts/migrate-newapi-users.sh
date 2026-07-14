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

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="${SUB2_DIR}/backups"
work_dir="$(mktemp -d)"
users_csv="${work_dir}/newapi-users.csv"
tokens_csv="${work_dir}/newapi-tokens.csv"
placeholder_report="${backup_dir}/newapi-migration-${timestamp}-placeholder-emails.csv"
backup_file="${backup_dir}/sub2api-before-newapi-migration-${timestamp}.dump"

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

group_platform="$(${sub_psql[@]} -Atc "SELECT platform FROM groups WHERE id=${OPENAI_GROUP_ID} AND deleted_at IS NULL AND status='active'")"
if [[ "${group_platform}" != "openai" ]]; then
  echo "OpenAI group ${OPENAI_GROUP_ID} is missing or inactive." >&2
  exit 1
fi

docker exec "${SUB2_DB_CONTAINER}" pg_dump \
  -U "${SUB2_DB_USER}" \
  -d "${SUB2_DB_NAME}" \
  --format=custom \
  --file=/tmp/sub2api-before-newapi-migration.dump
docker cp "${SUB2_DB_CONTAINER}:/tmp/sub2api-before-newapi-migration.dump" "${backup_file}"
docker exec "${SUB2_DB_CONTAINER}" rm -f /tmp/sub2api-before-newapi-migration.dump

"${new_psql[@]}" -Atc "COPY (
  SELECT
    id,
    left(coalesce(nullif(trim(username), ''), 'newapi_user_' || id::text), 100),
    CASE
      WHEN coalesce(trim(email), '') <> '' THEN lower(trim(email))
      ELSE 'newapi-' || id::text || '@migration.local'
    END,
    password,
    CASE WHEN role >= 100 THEN 'admin' ELSE 'user' END,
    CASE WHEN status = 1 THEN 'active' ELSE 'disabled' END,
    quota::numeric / 500000,
    to_timestamp(coalesce(nullif(created_at, 0), extract(epoch FROM now())::bigint)),
    CASE WHEN coalesce(last_login_at, 0) > 0 THEN to_timestamp(last_login_at) END,
    CASE
      WHEN coalesce(trim(email), '') = '' THEN 'Migrated from NewAPI user #' || id::text || '; replace placeholder email.'
      ELSE 'Migrated from NewAPI user #' || id::text
    END
  FROM users
  WHERE deleted_at IS NULL
  ORDER BY id
) TO STDOUT WITH (FORMAT CSV)" >"${users_csv}"

"${new_psql[@]}" -Atc "COPY (
  SELECT
    id,
    user_id,
    CASE WHEN key LIKE 'sk-%' THEN key ELSE 'sk-' || key END,
    left(coalesce(nullif(trim(name), ''), 'NewAPI Key ' || id::text), 100),
    CASE WHEN status = 1 THEN 'active' ELSE 'disabled' END,
    to_timestamp(coalesce(nullif(created_time, 0), extract(epoch FROM now())::bigint)),
    CASE WHEN coalesce(accessed_time, 0) > 0 THEN to_timestamp(accessed_time) END,
    CASE WHEN coalesce(expired_time, 0) > 0 THEN to_timestamp(expired_time) END,
    CASE WHEN unlimited_quota THEN 0 ELSE (coalesce(remain_quota, 0) + coalesce(used_quota, 0))::numeric / 500000 END,
    coalesce(used_quota, 0)::numeric / 500000
  FROM tokens
  WHERE deleted_at IS NULL
  ORDER BY id
) TO STDOUT WITH (FORMAT CSV)" >"${tokens_csv}"

"${sub_psql[@]}" -c "
  DROP TABLE IF EXISTS migration_newapi_users;
  DROP TABLE IF EXISTS migration_newapi_tokens;
  CREATE TABLE migration_newapi_users (
    old_id bigint PRIMARY KEY,
    username text NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    role text NOT NULL,
    status text NOT NULL,
    balance numeric NOT NULL,
    created_at timestamptz NOT NULL,
    last_login_at timestamptz,
    notes text NOT NULL
  );
  CREATE TABLE migration_newapi_tokens (
    old_id bigint PRIMARY KEY,
    old_user_id bigint NOT NULL,
    key text NOT NULL,
    name text NOT NULL,
    status text NOT NULL,
    created_at timestamptz NOT NULL,
    last_used_at timestamptz,
    expires_at timestamptz,
    quota numeric NOT NULL,
    quota_used numeric NOT NULL
  );
"

docker exec -i "${SUB2_DB_CONTAINER}" psql -X -v ON_ERROR_STOP=1 \
  -U "${SUB2_DB_USER}" -d "${SUB2_DB_NAME}" \
  -c "COPY migration_newapi_users FROM STDIN WITH (FORMAT CSV)" <"${users_csv}"
docker exec -i "${SUB2_DB_CONTAINER}" psql -X -v ON_ERROR_STOP=1 \
  -U "${SUB2_DB_USER}" -d "${SUB2_DB_NAME}" \
  -c "COPY migration_newapi_tokens FROM STDIN WITH (FORMAT CSV)" <"${tokens_csv}"

"${sub_psql[@]}" -c "
BEGIN;

INSERT INTO users (
  email, password_hash, role, balance, concurrency, status,
  created_at, updated_at, username, notes, total_recharged,
  signup_source, last_login_at, rpm_limit, frozen_balance
)
SELECT
  s.email, s.password_hash, s.role, s.balance, 5, s.status,
  s.created_at, now(), s.username, s.notes, 0,
  'email', s.last_login_at, 0, 0
FROM migration_newapi_users s
WHERE NOT EXISTS (
  SELECT 1 FROM users u
  WHERE u.deleted_at IS NULL AND lower(u.email) = lower(s.email)
);

CREATE TEMP TABLE migration_newapi_user_map ON COMMIT DROP AS
SELECT s.old_id, u.id AS new_id
FROM migration_newapi_users s
JOIN users u ON u.deleted_at IS NULL AND lower(u.email) = lower(s.email);

INSERT INTO user_allowed_groups (user_id, group_id, created_at)
SELECT m.new_id, ${OPENAI_GROUP_ID}, now()
FROM migration_newapi_user_map m
ON CONFLICT (user_id, group_id) DO NOTHING;

INSERT INTO api_keys (
  user_id, key, name, group_id, status, created_at, updated_at,
  ip_whitelist, ip_blacklist, quota, quota_used, expires_at,
  last_used_at, rate_limit_5h, rate_limit_1d, rate_limit_7d,
  usage_5h, usage_1d, usage_7d
)
SELECT
  m.new_id, t.key, t.name, ${OPENAI_GROUP_ID}, t.status,
  t.created_at, now(), '[]'::jsonb, '[]'::jsonb,
  t.quota, t.quota_used, t.expires_at, t.last_used_at,
  0, 0, 0, 0, 0, 0
FROM migration_newapi_tokens t
JOIN migration_newapi_user_map m ON m.old_id = t.old_user_id
WHERE NOT EXISTS (
  SELECT 1 FROM api_keys k WHERE k.key = t.key
);

COMMIT;
"

"${sub_psql[@]}" -AtF, -c "
  SELECT old_id, username, email
  FROM migration_newapi_users
  WHERE email LIKE '%@migration.local'
  ORDER BY old_id
" >"${placeholder_report}"

"${sub_psql[@]}" -P pager=off -c "
  SELECT 'migrated_users' AS item, count(*) AS count
  FROM users WHERE notes LIKE 'Migrated from NewAPI user #%'
  UNION ALL
  SELECT 'migrated_api_keys', count(*)
  FROM api_keys WHERE user_id IN (
    SELECT id FROM users WHERE notes LIKE 'Migrated from NewAPI user #%'
  )
  UNION ALL
  SELECT 'placeholder_emails', count(*)
  FROM users WHERE email LIKE '%@migration.local';
"

"${sub_psql[@]}" -c "DROP TABLE migration_newapi_tokens; DROP TABLE migration_newapi_users;"

docker restart "${SUB2_APP_CONTAINER}" >/dev/null

echo "Backup: ${backup_file}"
echo "Placeholder email report: ${placeholder_report}"
