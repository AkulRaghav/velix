// Package pgxstore implements the push service TokenStore over velixsql.
package pgxstore

import (
	"context"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/push/internal/handlers"
)

type TokenStore struct{}

func NewTokenStore() *TokenStore { return &TokenStore{} }

const insertSQL = `
INSERT INTO push_tokens
  (id, account_id, device_id, platform, token, webpush_subscription, registered_at, last_used_at, status)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`

func (s *TokenStore) Insert(ctx context.Context, tx velixsql.Tx, t handlers.Token) error {
	_, err := tx.Exec(ctx, insertSQL,
		t.ID, t.AccountID, t.DeviceID, t.Platform, t.Token,
		t.WebPushSubscription, t.RegisteredAt, t.LastUsedAt, t.Status)
	return err
}

const revokeSQL = `
UPDATE push_tokens SET status = 'revoked' WHERE id = $1 AND account_id = $2`

func (s *TokenStore) Revoke(ctx context.Context, tx velixsql.Tx, tokenID, accountID string) error {
	_, err := tx.Exec(ctx, revokeSQL, tokenID, accountID)
	return err
}

const listSQL = `
SELECT id, account_id, device_id, platform, token, webpush_subscription, registered_at, last_used_at, status
FROM push_tokens WHERE account_id = $1 AND status = 'active' ORDER BY registered_at`

func (s *TokenStore) List(ctx context.Context, tx velixsql.Tx, accountID string) ([]handlers.Token, error) {
	rows, err := tx.Query(ctx, listSQL, accountID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []handlers.Token
	for rows.Next() {
		var t handlers.Token
		if err := rows.Scan(&t.ID, &t.AccountID, &t.DeviceID, &t.Platform,
			&t.Token, &t.WebPushSubscription, &t.RegisteredAt, &t.LastUsedAt, &t.Status); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

var _ handlers.TokenStore = (*TokenStore)(nil)
