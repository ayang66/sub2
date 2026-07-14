#!/usr/bin/env bash

set -euo pipefail

SUB2_DIR="${SUB2_DIR:-/home/ubuntu/sub2api-deploy}"
SUB2_DB_CONTAINER="${SUB2_DB_CONTAINER:-sub2api-postgres}"
SUB2_APP_CONTAINER="${SUB2_APP_CONTAINER:-sub2api}"
SUB2_DB_USER="${SUB2_DB_USER:-sub2api}"
SUB2_DB_NAME="${SUB2_DB_NAME:-sub2api}"

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="${SUB2_DIR}/backups"
backup_file="${backup_dir}/sub2api-before-three-channel-config-${timestamp}.dump"

umask 077
mkdir -p "${backup_dir}"
chmod 700 "${backup_dir}"

docker exec "${SUB2_DB_CONTAINER}" pg_dump \
  -U "${SUB2_DB_USER}" \
  -d "${SUB2_DB_NAME}" \
  --format=custom \
  --file=/tmp/sub2api-before-three-channel-config.dump
docker cp "${SUB2_DB_CONTAINER}:/tmp/sub2api-before-three-channel-config.dump" "${backup_file}"
docker exec "${SUB2_DB_CONTAINER}" rm -f /tmp/sub2api-before-three-channel-config.dump

docker exec -i "${SUB2_DB_CONTAINER}" psql -X -v ON_ERROR_STOP=1 \
  -U "${SUB2_DB_USER}" -d "${SUB2_DB_NAME}" <<'SQL'
BEGIN;

UPDATE groups
SET name = 'GPT',
    description = '哈基米 GPT / Codex 模型分组',
    rate_multiplier = 0.05,
    platform = 'openai',
    status = 'active',
    allow_image_generation = true,
    updated_at = now()
WHERE id = 2;

UPDATE groups
SET name = 'Claude Kiro 低价版',
    description = 'Claude Kiro 低价模型分组',
    rate_multiplier = 0.12,
    platform = 'anthropic',
    status = 'active',
    updated_at = now()
WHERE id = 1;

INSERT INTO groups (
  name, description, rate_multiplier, is_exclusive, status,
  platform, subscription_type, default_validity_days,
  supported_model_scopes, allow_messages_dispatch,
  default_mapped_model, allow_image_generation
)
SELECT
  'Claude 满血版', 'Claude Opus / Sonnet 满血模型分组',
  1, false, 'active', 'anthropic', 'standard', 30,
  '["claude"]'::jsonb, true, 'claude-sonnet-4-6', false
WHERE NOT EXISTS (
  SELECT 1 FROM groups WHERE deleted_at IS NULL AND name = 'Claude 满血版'
);

UPDATE groups
SET description = 'Claude Opus / Sonnet 满血模型分组',
    rate_multiplier = 1,
    platform = 'anthropic',
    status = 'active',
    allow_messages_dispatch = true,
    default_mapped_model = 'claude-sonnet-4-6',
    updated_at = now()
WHERE deleted_at IS NULL AND name = 'Claude 满血版';

CREATE TEMP TABLE product_group_ids ON COMMIT DROP AS
SELECT
  2::bigint AS gpt_group_id,
  1::bigint AS kiro_group_id,
  (SELECT id FROM groups WHERE deleted_at IS NULL AND name = 'Claude 满血版' ORDER BY id LIMIT 1) AS full_group_id;

DELETE FROM account_groups
WHERE account_id IN (1, 2, 3, 4, 6);

INSERT INTO account_groups (account_id, group_id, priority, created_at)
VALUES
  (2, 2, 10, now()),
  (1, 2, 20, now()),
  (3, 2, 110, now()),
  (6, 1, 10, now());

INSERT INTO account_groups (account_id, group_id, priority, created_at)
SELECT 4, full_group_id, 10, now()
FROM product_group_ids;

UPDATE accounts
SET priority = 10,
    status = 'active',
    schedulable = true,
    error_message = NULL,
    updated_at = now()
WHERE id IN (2, 4, 6);

UPDATE accounts
SET platform = 'anthropic',
    extra = extra - 'openai_responses_mode' - 'openai_responses_supported',
    updated_at = now()
WHERE id = 4;

UPDATE accounts SET priority = 20, updated_at = now() WHERE id = 1;
UPDATE accounts SET priority = 110, updated_at = now() WHERE id = 3;

INSERT INTO user_allowed_groups (user_id, group_id, created_at)
SELECT u.id, g.group_id, now()
FROM users u
CROSS JOIN (
  SELECT gpt_group_id AS group_id FROM product_group_ids
  UNION ALL SELECT kiro_group_id FROM product_group_ids
  UNION ALL SELECT full_group_id FROM product_group_ids
) g
WHERE u.deleted_at IS NULL
ON CONFLICT (user_id, group_id) DO NOTHING;

INSERT INTO channels (
  name, description, status, model_mapping, billing_model_source,
  restrict_models, features, features_config, apply_pricing_to_account_stats
)
VALUES
  ('GPT', 'GPT / Codex 模型渠道', 'active', '{}'::jsonb, 'requested', true, '["Codex","Responses","Image"]', '{}'::jsonb, false),
  ('Claude Kiro 低价版', 'Claude Kiro 低价模型渠道', 'active', '{}'::jsonb, 'requested', true, '["Claude Code","低价"]', '{}'::jsonb, false),
  ('Claude 满血版', 'Claude Opus / Sonnet 满血模型渠道', 'active', '{}'::jsonb, 'requested', true, '["Claude Code","Opus","Sonnet"]', '{}'::jsonb, false)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  status = EXCLUDED.status,
  model_mapping = EXCLUDED.model_mapping,
  billing_model_source = EXCLUDED.billing_model_source,
  restrict_models = EXCLUDED.restrict_models,
  features = EXCLUDED.features,
  features_config = EXCLUDED.features_config,
  apply_pricing_to_account_stats = EXCLUDED.apply_pricing_to_account_stats,
  updated_at = now();

CREATE TEMP TABLE product_channel_ids ON COMMIT DROP AS
SELECT
  (SELECT id FROM channels WHERE name = 'GPT') AS gpt_channel_id,
  (SELECT id FROM channels WHERE name = 'Claude Kiro 低价版') AS kiro_channel_id,
  (SELECT id FROM channels WHERE name = 'Claude 满血版') AS full_channel_id;

DELETE FROM channel_groups
WHERE group_id IN (
  SELECT gpt_group_id FROM product_group_ids
  UNION ALL SELECT kiro_group_id FROM product_group_ids
  UNION ALL SELECT full_group_id FROM product_group_ids
);

INSERT INTO channel_groups (channel_id, group_id, created_at)
SELECT gpt_channel_id, gpt_group_id, now() FROM product_channel_ids, product_group_ids
UNION ALL
SELECT kiro_channel_id, kiro_group_id, now() FROM product_channel_ids, product_group_ids
UNION ALL
SELECT full_channel_id, full_group_id, now() FROM product_channel_ids, product_group_ids;

DELETE FROM channel_model_pricing
WHERE channel_id IN (
  SELECT gpt_channel_id FROM product_channel_ids
  UNION ALL SELECT kiro_channel_id FROM product_channel_ids
  UNION ALL SELECT full_channel_id FROM product_channel_ids
);

-- Official list prices, expressed per token.
INSERT INTO channel_model_pricing (
  channel_id, platform, models, billing_mode,
  input_price, output_price, cache_write_price, cache_read_price
)
SELECT gpt_channel_id, 'openai', '["gpt-5.6","gpt-5.6-sol"]'::jsonb, 'token', 0.000005, 0.000030, 0.00000625, 0.0000005 FROM product_channel_ids
UNION ALL
SELECT gpt_channel_id, 'openai', '["gpt-5.6-terra"]'::jsonb, 'token', 0.0000025, 0.000015, 0.000003125, 0.00000025 FROM product_channel_ids
UNION ALL
SELECT gpt_channel_id, 'openai', '["gpt-5.6-luna"]'::jsonb, 'token', 0.000001, 0.000006, 0.00000125, 0.0000001 FROM product_channel_ids
UNION ALL
SELECT gpt_channel_id, 'openai', '["gpt-5.5"]'::jsonb, 'token', 0.000005, 0.000030, NULL, 0.0000005 FROM product_channel_ids
UNION ALL
SELECT gpt_channel_id, 'openai', '["gpt-5.4"]'::jsonb, 'token', 0.0000025, 0.000015, NULL, 0.00000025 FROM product_channel_ids
UNION ALL
SELECT gpt_channel_id, 'openai', '["gpt-5.4-mini"]'::jsonb, 'token', 0.00000075, 0.0000045, NULL, 0.000000075 FROM product_channel_ids
UNION ALL
SELECT gpt_channel_id, 'openai', '["gpt-5.3-codex-spark"]'::jsonb, 'token', 0.00000175, 0.000014, NULL, 0.000000175 FROM product_channel_ids
UNION ALL
SELECT gpt_channel_id, 'openai', '["gpt-5.2","gpt-5.3","gpt-5.3-spark","codex-auto-review","gpt-oss-120b"]'::jsonb, 'token', NULL, NULL, NULL, NULL FROM product_channel_ids;

INSERT INTO channel_model_pricing (
  channel_id, platform, models, billing_mode, image_output_price, per_request_price
)
SELECT gpt_channel_id, 'openai', '["gpt-image-2","gpt-image-1.5"]'::jsonb, 'image', 0.04, 0.04
FROM product_channel_ids;

-- Claude official list pricing for the Kiro product channel.
INSERT INTO channel_model_pricing (
  channel_id, platform, models, billing_mode,
  input_price, output_price, cache_write_price, cache_read_price
)
SELECT kiro_channel_id, 'anthropic', '["claude-opus-4-7","claude-opus-4-7-thinking"]'::jsonb, 'token', 0.000005, 0.000025, 0.00000625, 0.0000005 FROM product_channel_ids
UNION ALL
SELECT kiro_channel_id, 'anthropic', '["claude-opus-4-8","claude-opus-4-8-thinking"]'::jsonb, 'token', 0.000005, 0.000025, 0.00000625, 0.0000005 FROM product_channel_ids;

-- Claude full-price tier.
INSERT INTO channel_model_pricing (
  channel_id, platform, models, billing_mode,
  input_price, output_price, cache_write_price, cache_read_price
)
SELECT full_channel_id, 'anthropic', '["claude-opus-4-6","claude-opus-4-7","claude-opus-4-8"]'::jsonb, 'token', 0.000005, 0.000025, 0.00000625, 0.0000005 FROM product_channel_ids
UNION ALL
SELECT full_channel_id, 'anthropic', '["claude-sonnet-4-6"]'::jsonb, 'token', 0.000003, 0.000015, 0.00000375, 0.0000003 FROM product_channel_ids
UNION ALL
SELECT full_channel_id, 'anthropic', '["claude-fable-5"]'::jsonb, 'token', 0.00001, 0.00005, 0.0000125, 0.000001 FROM product_channel_ids
UNION ALL
SELECT full_channel_id, 'anthropic', '["claude-sonnet-5"]'::jsonb, 'token', 0.000002, 0.00001, 0.0000025, 0.0000002 FROM product_channel_ids;

COMMIT;
SQL

docker restart "${SUB2_APP_CONTAINER}" >/dev/null

echo "Backup: ${backup_file}"
