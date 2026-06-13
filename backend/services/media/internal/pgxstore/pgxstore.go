// Package pgxstore implements the media service MediaStore over velixsql.
package pgxstore

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/media/internal/handlers"
)

// MediaStore implements handlers.MediaStore.
type MediaStore struct{}

func NewMediaStore() *MediaStore { return &MediaStore{} }

const insertPendingSQL = `
INSERT INTO media_objects (id, owner_account_id, content_type_class, size_bytes, state, created_at)
VALUES ($1, $2, $3, $4, $5, $6)`

func (s *MediaStore) InsertPending(ctx context.Context, tx velixsql.Tx, m handlers.MediaRow) error {
	_, err := tx.Exec(ctx, insertPendingSQL,
		m.ID, m.OwnerAccountID, m.ContentTypeClass, m.SizeBytes, m.State, m.CreatedAt)
	return err
}

const getByIDSQL = `
SELECT id, owner_account_id, content_type_class, size_bytes, state, ciphertext_blake3, created_at, finalized_at
FROM media_objects WHERE id = $1`

func (s *MediaStore) GetByID(ctx context.Context, tx velixsql.Tx, id string) (handlers.MediaRow, error) {
	var m handlers.MediaRow
	err := tx.QueryRow(ctx, getByIDSQL, id).Scan(
		&m.ID, &m.OwnerAccountID, &m.ContentTypeClass, &m.SizeBytes,
		&m.State, &m.CiphertextBlake3, &m.CreatedAt, &m.FinalizedAt)
	return m, err
}

const markUploadedSQL = `
UPDATE media_objects SET state = 'uploaded', ciphertext_blake3 = $2, finalized_at = $3 WHERE id = $1`

func (s *MediaStore) MarkUploaded(ctx context.Context, tx velixsql.Tx, id string, b3 []byte, at time.Time) error {
	_, err := tx.Exec(ctx, markUploadedSQL, id, b3, at)
	return err
}

const markDeletedSQL = `
UPDATE media_objects SET state = 'deleted', deleted_at = $2 WHERE id = $1`

func (s *MediaStore) MarkDeleted(ctx context.Context, tx velixsql.Tx, id string, at time.Time) error {
	_, err := tx.Exec(ctx, markDeletedSQL, id, at)
	return err
}

var _ handlers.MediaStore = (*MediaStore)(nil)
