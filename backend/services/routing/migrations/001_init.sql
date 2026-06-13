-- +goose Up
-- +goose StatementBegin

CREATE TABLE message_envelope (
  id                    text PRIMARY KEY,
  recipient_account_id  text NOT NULL,
  recipient_device_id   text NOT NULL,
  ciphertext            bytea NOT NULL,
  enqueued_at           timestamptz NOT NULL DEFAULT now(),
  ttl_at                timestamptz NOT NULL,
  attempts              int NOT NULL DEFAULT 0,
  last_attempt_at       timestamptz,
  delivered_at          timestamptz,
  -- Reconciler scans for envelopes whose initial NATS publish failed.
  -- After a successful publish, this is set; the reconciler ignores them.
  nats_published_at     timestamptz
);

-- Hot lookup: live drain on reconnect (per-device, undelivered, ordered).
CREATE INDEX idx_envelope_recipient_undelivered
  ON message_envelope(recipient_device_id, enqueued_at)
  WHERE delivered_at IS NULL;

-- Sweeper for TTL pruning.
CREATE INDEX idx_envelope_ttl_at ON message_envelope(ttl_at);

-- Reconciler index for unpublished envelopes.
CREATE INDEX idx_envelope_unpublished
  ON message_envelope(enqueued_at)
  WHERE nats_published_at IS NULL;

CREATE TABLE delivery_state (
  message_id  text NOT NULL,
  device_id   text NOT NULL,
  state       text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, device_id)
);

CREATE TABLE idempotency_keys (
  account_id     text NOT NULL,
  key            text NOT NULL,
  response_blob  bytea NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL,
  PRIMARY KEY (account_id, key)
);

CREATE INDEX idx_idem_expires_at ON idempotency_keys(expires_at);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS idempotency_keys;
DROP TABLE IF EXISTS delivery_state;
DROP TABLE IF EXISTS message_envelope;
-- +goose StatementEnd
