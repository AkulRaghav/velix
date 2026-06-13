-- +goose Up
-- +goose StatementBegin

CREATE TABLE deliveries (
  id            text PRIMARY KEY,
  event_id      text NOT NULL UNIQUE,
  device_id     text NOT NULL,
  platform      text NOT NULL,
  state         text NOT NULL DEFAULT 'queued',
  reason        text,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_deliveries_state ON deliveries(state);
CREATE INDEX idx_deliveries_device ON deliveries(device_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS deliveries;
-- +goose StatementEnd
