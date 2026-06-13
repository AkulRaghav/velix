-- +goose Up
-- +goose StatementBegin

CREATE TABLE push_tokens (
  id                    text PRIMARY KEY,
  account_id            text NOT NULL,
  device_id             text NOT NULL,
  platform              text NOT NULL,
  token                 bytea,
  webpush_subscription  bytea,
  registered_at         timestamptz NOT NULL DEFAULT now(),
  last_used_at          timestamptz NOT NULL DEFAULT now(),
  status                text NOT NULL DEFAULT 'active'
);

CREATE INDEX idx_push_tokens_account ON push_tokens(account_id);
CREATE INDEX idx_push_tokens_device  ON push_tokens(device_id);
CREATE UNIQUE INDEX idx_push_tokens_unique
  ON push_tokens(account_id, device_id, platform)
  WHERE status = 'active';

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS push_tokens;
-- +goose StatementEnd
