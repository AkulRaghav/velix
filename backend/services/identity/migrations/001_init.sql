-- +goose Up
-- +goose StatementBegin

CREATE TABLE accounts (
  id                     text PRIMARY KEY,
  identity_pubkey_hash   bytea NOT NULL UNIQUE,
  locale                 text NOT NULL DEFAULT 'en',
  status                 text NOT NULL DEFAULT 'active',
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE handles (
  handle      text PRIMARY KEY,
  account_id  text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  reserved_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_handles_account_id ON handles(account_id);

CREATE TABLE devices (
  id                  text PRIMARY KEY,
  account_id          text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_pubkey       bytea NOT NULL,
  device_pubkey_hash  bytea NOT NULL UNIQUE,
  name                text NOT NULL,
  platform            text NOT NULL,
  status              text NOT NULL DEFAULT 'active',
  paired_at           timestamptz NOT NULL DEFAULT now(),
  last_seen_at        timestamptz NOT NULL DEFAULT now(),
  attestation_sig     bytea NOT NULL
);

CREATE INDEX idx_devices_account_active ON devices(account_id) WHERE status = 'active';

CREATE TABLE prekey_bundles (
  account_id    text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_id     text NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  signed_prekey bytea NOT NULL,
  signed_prekey_signature bytea NOT NULL,
  signed_at     timestamptz NOT NULL,
  PRIMARY KEY (account_id, device_id)
);

CREATE TABLE one_time_prekeys (
  id          bigserial PRIMARY KEY,
  account_id  text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_id   text NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  prekey      bytea NOT NULL,
  consumed_at timestamptz
);

CREATE INDEX idx_otpk_unconsumed
  ON one_time_prekeys(account_id, device_id)
  WHERE consumed_at IS NULL;

CREATE TABLE refresh_sessions (
  id                  text PRIMARY KEY,
  account_id          text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_id           text NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  refresh_token_hash  bytea NOT NULL,
  user_agent          text,
  expires_at          timestamptz NOT NULL,
  revoked_at          timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_sessions_account ON refresh_sessions(account_id);
CREATE INDEX idx_refresh_sessions_active_expiry
  ON refresh_sessions(expires_at)
  WHERE revoked_at IS NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS refresh_sessions;
DROP TABLE IF EXISTS one_time_prekeys;
DROP TABLE IF EXISTS prekey_bundles;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS handles;
DROP TABLE IF EXISTS accounts;
-- +goose StatementEnd
