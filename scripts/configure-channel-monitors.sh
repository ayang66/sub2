#!/usr/bin/env bash

set -euo pipefail

SUB2_DIR="${SUB2_DIR:-/home/ubuntu/sub2api-deploy}"
SUB2_DB_CONTAINER="${SUB2_DB_CONTAINER:-sub2api-postgres}"
SUB2_APP_CONTAINER="${SUB2_APP_CONTAINER:-sub2api}"
SUB2_DB_USER="${SUB2_DB_USER:-sub2api}"
SUB2_DB_NAME="${SUB2_DB_NAME:-sub2api}"
MONITOR_ENDPOINT="${MONITOR_ENDPOINT:-https://sub2.43-135-186-16.sslip.io}"
MONITOR_USER_ID="${MONITOR_USER_ID:-1}"
MONITOR_INTERVAL_SECONDS="${MONITOR_INTERVAL_SECONDS:-300}"
MONITOR_JITTER_SECONDS="${MONITOR_JITTER_SECONDS:-30}"

set -a
# shellcheck disable=SC1091
source "${SUB2_DIR}/.env"
set +a

: "${TOTP_ENCRYPTION_KEY:?TOTP_ENCRYPTION_KEY is required}"

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="${SUB2_DIR}/backups"
backup_file="${backup_dir}/sub2api-before-channel-monitors-${timestamp}.dump"

umask 077
mkdir -p "${backup_dir}"

db_psql=(
  docker exec -i "${SUB2_DB_CONTAINER}"
  psql -X -v ON_ERROR_STOP=1 -U "${SUB2_DB_USER}" -d "${SUB2_DB_NAME}"
)

docker exec "${SUB2_DB_CONTAINER}" pg_dump \
  -U "${SUB2_DB_USER}" \
  -d "${SUB2_DB_NAME}" \
  --format=custom \
  --file=/tmp/sub2api-before-channel-monitors.dump
docker cp "${SUB2_DB_CONTAINER}:/tmp/sub2api-before-channel-monitors.dump" "${backup_file}"
docker exec "${SUB2_DB_CONTAINER}" rm -f /tmp/sub2api-before-channel-monitors.dump

admin_exists="$(${db_psql[@]} -Atc "SELECT count(*) FROM users WHERE id=${MONITOR_USER_ID} AND deleted_at IS NULL AND status='active'")"
if [[ "${admin_exists}" != "1" ]]; then
  echo "Monitor user ${MONITOR_USER_ID} is missing or inactive." >&2
  exit 1
fi

get_or_create_key() {
  local name="$1"
  local group_id="$2"
  local key

  key="$("${db_psql[@]}" -qAt -v key_name="${name}" <<'SQL'
SELECT key
FROM api_keys
WHERE deleted_at IS NULL AND name = :'key_name'
ORDER BY id
LIMIT 1;
SQL
)" || return 1

  if [[ -z "${key}" ]]; then
    key="sk-mon-$(openssl rand -hex 24)"
    "${db_psql[@]}" -q \
      -v user_id="${MONITOR_USER_ID}" \
      -v group_id="${group_id}" \
      -v api_key="${key}" \
      -v key_name="${name}" >/dev/null <<'SQL'
INSERT INTO api_keys (
  user_id, key, name, group_id, status,
  ip_whitelist, ip_blacklist, quota, quota_used,
  rate_limit_5h, rate_limit_1d, rate_limit_7d,
  usage_5h, usage_1d, usage_7d
) VALUES (
  :'user_id'::bigint, :'api_key', :'key_name', :'group_id'::bigint, 'active',
  '[]'::jsonb, '[]'::jsonb, 10, 0,
  0.5, 1, 5,
  0, 0, 0
);
SQL
  else
    "${db_psql[@]}" -q \
      -v group_id="${group_id}" \
      -v key_name="${name}" >/dev/null <<'SQL'
UPDATE api_keys
SET group_id = :'group_id'::bigint,
    status = 'active',
    quota = 10,
    rate_limit_5h = 0.5,
    rate_limit_1d = 1,
    rate_limit_7d = 5,
    updated_at = now()
WHERE deleted_at IS NULL AND name = :'key_name';
SQL
  fi

  printf '%s' "${key}"
}

encrypt_key() {
  MONITOR_PLAIN_KEY="$1" python3 - <<'PY'
import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

key = bytes.fromhex(os.environ["TOTP_ENCRYPTION_KEY"])
nonce = os.urandom(12)
ciphertext = AESGCM(key).encrypt(nonce, os.environ["MONITOR_PLAIN_KEY"].encode(), None)
print(base64.b64encode(nonce + ciphertext).decode(), end="")
PY
}

upsert_monitor() {
  local name="$1"
  local provider="$2"
  local api_mode="$3"
  local primary_model="$4"
  local group_name="$5"
  local encrypted_key="$6"

  "${db_psql[@]}" -q \
    -v monitor_name="${name}" \
    -v provider="${provider}" \
    -v api_mode="${api_mode}" \
    -v endpoint="${MONITOR_ENDPOINT}" \
    -v encrypted_key="${encrypted_key}" \
    -v primary_model="${primary_model}" \
    -v group_name="${group_name}" \
    -v interval_seconds="${MONITOR_INTERVAL_SECONDS}" \
    -v jitter_seconds="${MONITOR_JITTER_SECONDS}" \
    -v created_by="${MONITOR_USER_ID}" >/dev/null <<'SQL'
INSERT INTO channel_monitors (
  name, provider, api_mode, endpoint, api_key_encrypted,
  primary_model, extra_models, group_name, enabled,
  interval_seconds, jitter_seconds, created_by,
  extra_headers, body_override_mode
)
SELECT
  :'monitor_name', :'provider', :'api_mode', :'endpoint', :'encrypted_key',
  :'primary_model', '[]'::jsonb, :'group_name', true,
  :'interval_seconds'::int, :'jitter_seconds'::int, :'created_by'::bigint,
  '{}'::jsonb, 'off'
WHERE NOT EXISTS (
  SELECT 1 FROM channel_monitors WHERE name = :'monitor_name'
);

UPDATE channel_monitors
SET provider = :'provider',
    api_mode = :'api_mode',
    endpoint = :'endpoint',
    api_key_encrypted = :'encrypted_key',
    primary_model = :'primary_model',
    extra_models = '[]'::jsonb,
    group_name = :'group_name',
    enabled = true,
    interval_seconds = :'interval_seconds'::int,
    jitter_seconds = :'jitter_seconds'::int,
    created_by = :'created_by'::bigint,
    extra_headers = '{}'::jsonb,
    body_override_mode = 'off',
    body_override = NULL,
    updated_at = now()
WHERE name = :'monitor_name';
SQL
}

gpt_key="$(get_or_create_key "Monitor GPT" 2)"
kiro_key="$(get_or_create_key "Monitor Claude Kiro" 1)"
full_key="$(get_or_create_key "Monitor Claude Full" 4)"

upsert_monitor "GPT" "openai" "responses" "gpt-5.5" "GPT" "$(encrypt_key "${gpt_key}")"
upsert_monitor "Claude Kiro 低价版" "anthropic" "chat_completions" "claude-opus-4-7" "Claude Kiro 低价版" "$(encrypt_key "${kiro_key}")"
upsert_monitor "Claude 满血版" "anthropic" "chat_completions" "claude-sonnet-4-6" "Claude 满血版" "$(encrypt_key "${full_key}")"

"${db_psql[@]}" -q -c "
  INSERT INTO settings (key, value)
  VALUES
    ('channel_monitor_enabled', 'true'),
    ('channel_monitor_default_interval_seconds', '${MONITOR_INTERVAL_SECONDS}')
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value,
      updated_at = now();
" >/dev/null

docker restart "${SUB2_APP_CONTAINER}" >/dev/null

echo "Backup: ${backup_file}"
