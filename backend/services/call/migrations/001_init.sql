-- +goose Up
-- +goose StatementBegin

CREATE TABLE calls (
  id              text PRIMARY KEY,
  conversation_id text NOT NULL,
  mode            text NOT NULL,
  security_mode   text NOT NULL DEFAULT 'e2ee',
  started_by      text NOT NULL,
  started_at      timestamptz NOT NULL DEFAULT now(),
  ended_at        timestamptz,
  state           text NOT NULL DEFAULT 'live'
);

CREATE INDEX idx_calls_conversation ON calls(conversation_id);
CREATE INDEX idx_calls_live ON calls(state) WHERE state = 'live';

CREATE TABLE call_participants (
  call_id    text NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
  account_id text NOT NULL,
  device_id  text NOT NULL,
  joined_at  timestamptz NOT NULL DEFAULT now(),
  left_at    timestamptz,
  left_reason text,
  PRIMARY KEY (call_id, account_id, device_id)
);

CREATE INDEX idx_call_participants_account ON call_participants(account_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS call_participants;
DROP TABLE IF EXISTS calls;
-- +goose StatementEnd
