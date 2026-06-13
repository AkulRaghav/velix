package pgxstore

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/identity/internal/handlers"
)

// PrekeyStore implements handlers.PrekeyStore.
type PrekeyStore struct{}

func NewPrekeyStore() *PrekeyStore { return &PrekeyStore{} }

const upsertSignedPrekeySQL = `
INSERT INTO prekey_bundles (account_id, device_id, signed_prekey, signed_prekey_signature, signed_at)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (account_id, device_id)
DO UPDATE SET signed_prekey = EXCLUDED.signed_prekey,
              signed_prekey_signature = EXCLUDED.signed_prekey_signature,
              signed_at = EXCLUDED.signed_at`

func (s *PrekeyStore) UpsertSignedPrekey(
	ctx context.Context, tx velixsql.Tx, accountID, deviceID string,
	signedPrekey, signature []byte, signedAt time.Time,
) error {
	_, err := tx.Exec(ctx, upsertSignedPrekeySQL,
		accountID, deviceID, signedPrekey, signature, signedAt)
	return err
}

const insertOTPKSQL = `
INSERT INTO one_time_prekeys (account_id, device_id, prekey) VALUES ($1, $2, $3)`

func (s *PrekeyStore) InsertOneTimePrekeys(
	ctx context.Context, tx velixsql.Tx, accountID, deviceID string, prekeys [][]byte,
) error {
	for _, k := range prekeys {
		if _, err := tx.Exec(ctx, insertOTPKSQL, accountID, deviceID, k); err != nil {
			return err
		}
	}
	return nil
}

// consumeOTPKSQL atomically claims the lowest-id unconsumed prekey.
const consumeOTPKSQL = `
UPDATE one_time_prekeys SET consumed_at = now()
WHERE id = (
  SELECT id FROM one_time_prekeys
  WHERE account_id = $1 AND device_id = $2 AND consumed_at IS NULL
  ORDER BY id LIMIT 1
  FOR UPDATE SKIP LOCKED
)
RETURNING prekey`

func (s *PrekeyStore) ConsumeOneTimePrekey(
	ctx context.Context, tx velixsql.Tx, accountID, deviceID string,
) ([]byte, error) {
	var prekey []byte
	err := tx.QueryRow(ctx, consumeOTPKSQL, accountID, deviceID).Scan(&prekey)
	if err == velixsql.ErrNoRows {
		return nil, nil // no OTPK available is not an error
	}
	if err != nil {
		return nil, err
	}
	return prekey, nil
}

const getSignedPrekeySQL = `
SELECT signed_prekey, signed_prekey_signature
FROM prekey_bundles WHERE account_id = $1 AND device_id = $2`

func (s *PrekeyStore) GetSignedPrekey(
	ctx context.Context, tx velixsql.Tx, accountID, deviceID string,
) ([]byte, []byte, error) {
	var sp, sig []byte
	err := tx.QueryRow(ctx, getSignedPrekeySQL, accountID, deviceID).Scan(&sp, &sig)
	return sp, sig, err
}

const getIdentityPubkeySQL = `
SELECT device_pubkey FROM devices
WHERE account_id = $1 AND status = 'active'
ORDER BY paired_at LIMIT 1`

func (s *PrekeyStore) GetIdentityPublicKey(
	ctx context.Context, tx velixsql.Tx, accountID string,
) ([]byte, error) {
	var pub []byte
	err := tx.QueryRow(ctx, getIdentityPubkeySQL, accountID).Scan(&pub)
	return pub, err
}

var _ handlers.PrekeyStore = (*PrekeyStore)(nil)
