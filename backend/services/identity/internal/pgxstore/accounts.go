// Package pgxstore implements the identity service's store interfaces over
// the velixsql seam (pgx-backed in production). Every method runs inside the
// caller-provided transaction; no method opens its own connection.
package pgxstore

import (
	"context"
	"errors"
	"time"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/identity/internal/handlers"
)

// AccountStore implements handlers.AccountStore.
type AccountStore struct{}

func NewAccountStore() *AccountStore { return &AccountStore{} }

const insertAccountSQL = `
INSERT INTO accounts (id, identity_pubkey_hash, locale, status, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $5)`

func (s *AccountStore) InsertAccount(
	ctx context.Context, tx velixsql.Tx, a handlers.Account, identityPubkey []byte,
) error {
	_ = identityPubkey // pubkey is hashed by the caller into a.IdentityPubkeyHash
	_, err := tx.Exec(ctx, insertAccountSQL,
		a.ID, a.IdentityPubkeyHash, a.Locale, a.Status, a.CreatedAt)
	return err
}

const getAccountSQL = `
SELECT id, identity_pubkey_hash, locale, status, created_at
FROM accounts WHERE id = $1`

func (s *AccountStore) GetAccountByID(
	ctx context.Context, tx velixsql.Tx, id string,
) (handlers.Account, error) {
	var a handlers.Account
	err := tx.QueryRow(ctx, getAccountSQL, id).Scan(
		&a.ID, &a.IdentityPubkeyHash, &a.Locale, &a.Status, &a.CreatedAt)
	if errors.Is(err, velixsql.ErrNoRows) {
		return handlers.Account{}, velixsql.ErrNoRows
	}
	return a, err
}

const updateLocaleSQL = `UPDATE accounts SET locale = $2, updated_at = now() WHERE id = $1`

func (s *AccountStore) UpdateLocale(
	ctx context.Context, tx velixsql.Tx, id, locale string,
) error {
	_, err := tx.Exec(ctx, updateLocaleSQL, id, locale)
	return err
}

const reserveHandleSQL = `
INSERT INTO handles (handle, account_id, reserved_at) VALUES ($1, $2, $3)`

func (s *AccountStore) ReserveHandle(
	ctx context.Context, tx velixsql.Tx, accountID, handle string,
) error {
	_, err := tx.Exec(ctx, reserveHandleSQL, handle, accountID, time.Now().UTC())
	return err
}

const updateProfileSQL = `
UPDATE accounts SET updated_at = now() WHERE id = $1
RETURNING id, identity_pubkey_hash, locale, status, created_at`

func (s *AccountStore) UpdateProfile(
	ctx context.Context, tx velixsql.Tx, accountID, displayNameHash, handle string,
) (handlers.Account, error) {
	if handle != "" {
		if err := s.ReserveHandle(ctx, tx, accountID, handle); err != nil {
			return handlers.Account{}, err
		}
	}
	_ = displayNameHash // display-name hashing handled by the caller
	var a handlers.Account
	err := tx.QueryRow(ctx, updateProfileSQL, accountID).Scan(
		&a.ID, &a.IdentityPubkeyHash, &a.Locale, &a.Status, &a.CreatedAt)
	return a, err
}

var _ handlers.AccountStore = (*AccountStore)(nil)
