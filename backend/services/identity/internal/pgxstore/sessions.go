package pgxstore

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/identity/internal/handlers"
)

// SessionStore implements handlers.SessionStore.
type SessionStore struct{}

func NewSessionStore() *SessionStore { return &SessionStore{} }

const insertSessionSQL = `
INSERT INTO refresh_sessions (id, account_id, device_id, refresh_token_hash, expires_at)
VALUES ($1, $2, $3, $4, $5)`

func (s *SessionStore) InsertSession(
	ctx context.Context, tx velixsql.Tx, sessionID, accountID, deviceID string,
	refreshTokenHash []byte, expiresAt time.Time,
) error {
	_, err := tx.Exec(ctx, insertSessionSQL,
		sessionID, accountID, deviceID, refreshTokenHash, expiresAt)
	return err
}

const revokeSessionSQL = `UPDATE refresh_sessions SET revoked_at = now() WHERE id = $1`

func (s *SessionStore) RevokeSession(
	ctx context.Context, tx velixsql.Tx, sessionID string,
) error {
	_, err := tx.Exec(ctx, revokeSessionSQL, sessionID)
	return err
}

const getActiveSessionSQL = `
SELECT id, account_id, device_id, expires_at
FROM refresh_sessions
WHERE refresh_token_hash = $1 AND revoked_at IS NULL AND expires_at > now()`

func (s *SessionStore) GetActiveSessionByRefreshHash(
	ctx context.Context, tx velixsql.Tx, hash []byte,
) (sessionID, accountID, deviceID string, expiresAt time.Time, err error) {
	err = tx.QueryRow(ctx, getActiveSessionSQL, hash).Scan(
		&sessionID, &accountID, &deviceID, &expiresAt)
	return
}

const rotateRefreshSQL = `
UPDATE refresh_sessions SET refresh_token_hash = $2, expires_at = $3 WHERE id = $1`

func (s *SessionStore) RotateRefreshToken(
	ctx context.Context, tx velixsql.Tx, sessionID string, newHash []byte, newExpiresAt time.Time,
) error {
	_, err := tx.Exec(ctx, rotateRefreshSQL, sessionID, newHash, newExpiresAt)
	return err
}

var _ handlers.SessionStore = (*SessionStore)(nil)
