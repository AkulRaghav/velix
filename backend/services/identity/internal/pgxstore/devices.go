package pgxstore

import (
	"context"
	"crypto/sha256"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/identity/internal/handlers"
)

// DeviceStore implements handlers.DeviceStore.
type DeviceStore struct{}

func NewDeviceStore() *DeviceStore { return &DeviceStore{} }

const insertDeviceSQL = `
INSERT INTO devices
  (id, account_id, device_pubkey, device_pubkey_hash, name, platform, status, paired_at, last_seen_at, attestation_sig)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`

func (s *DeviceStore) InsertDevice(
	ctx context.Context, tx velixsql.Tx, d handlers.Device, devicePubkey, attestationSig []byte,
) error {
	hash := sha256.Sum256(devicePubkey)
	_, err := tx.Exec(ctx, insertDeviceSQL,
		d.ID, d.AccountID, devicePubkey, hash[:], d.Name, d.Platform,
		d.Status, d.PairedAt, d.LastSeenAt, attestationSig)
	return err
}

const getDeviceSQL = `
SELECT id, account_id, name, platform, paired_at, last_seen_at, status
FROM devices WHERE id = $1`

func (s *DeviceStore) GetDeviceByID(
	ctx context.Context, tx velixsql.Tx, id string,
) (handlers.Device, error) {
	var d handlers.Device
	err := tx.QueryRow(ctx, getDeviceSQL, id).Scan(
		&d.ID, &d.AccountID, &d.Name, &d.Platform, &d.PairedAt, &d.LastSeenAt, &d.Status)
	return d, err
}

const listDevicesSQL = `
SELECT id, account_id, name, platform, paired_at, last_seen_at, status
FROM devices WHERE account_id = $1 AND status = 'active'
ORDER BY paired_at`

func (s *DeviceStore) ListDevicesByAccount(
	ctx context.Context, tx velixsql.Tx, accountID string,
) ([]handlers.Device, error) {
	rows, err := tx.Query(ctx, listDevicesSQL, accountID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []handlers.Device
	for rows.Next() {
		var d handlers.Device
		if err := rows.Scan(&d.ID, &d.AccountID, &d.Name, &d.Platform,
			&d.PairedAt, &d.LastSeenAt, &d.Status); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

const revokeDeviceSQL = `UPDATE devices SET status = 'revoked' WHERE id = $1`

func (s *DeviceStore) RevokeDevice(
	ctx context.Context, tx velixsql.Tx, deviceID, reason string,
) error {
	_ = reason
	_, err := tx.Exec(ctx, revokeDeviceSQL, deviceID)
	return err
}

var _ handlers.DeviceStore = (*DeviceStore)(nil)
