-- +goose Up
-- +goose StatementBegin

CREATE TABLE media_objects (
  id                  text PRIMARY KEY,
  owner_account_id    text NOT NULL,
  content_type_class  text NOT NULL,
  size_bytes          bigint NOT NULL,
  state               text NOT NULL DEFAULT 'pending',
  ciphertext_blake3   bytea,
  created_at          timestamptz NOT NULL DEFAULT now(),
  finalized_at        timestamptz,
  deleted_at          timestamptz
);

CREATE INDEX idx_media_owner_state ON media_objects(owner_account_id, state);
CREATE INDEX idx_media_deletion_pending ON media_objects(deleted_at) WHERE deleted_at IS NOT NULL;

-- Reconciler index for pending uploads that never finalized; sweeps after 24h.
CREATE INDEX idx_media_pending_old ON media_objects(created_at)
  WHERE state = 'pending';

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS media_objects;
-- +goose StatementEnd
