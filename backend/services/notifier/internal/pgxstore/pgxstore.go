// Package pgxstore implements the notifier service DeliveryStore over velixsql.
package pgxstore

import (
	"context"
	"errors"
	"time"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/notifier/internal/handlers"
)

type DeliveryStore struct{}

func NewDeliveryStore() *DeliveryStore { return &DeliveryStore{} }

const insertSQL = `
INSERT INTO deliveries (id, event_id, device_id, platform, state, updated_at)
VALUES ($1, $2, $3, $4, $5, $6)`

func (s *DeliveryStore) Insert(ctx context.Context, tx velixsql.Tx, d handlers.Delivery) error {
	_, err := tx.Exec(ctx, insertSQL, d.ID, d.EventID, d.DeviceID, d.Platform, d.State, d.UpdatedAt)
	return err
}

const getByIDSQL = `
SELECT id, event_id, device_id, platform, state, reason, updated_at FROM deliveries WHERE id = $1`

func (s *DeliveryStore) GetByID(ctx context.Context, tx velixsql.Tx, id string) (handlers.Delivery, error) {
	var d handlers.Delivery
	var reason *string
	err := tx.QueryRow(ctx, getByIDSQL, id).Scan(
		&d.ID, &d.EventID, &d.DeviceID, &d.Platform, &d.State, &reason, &d.UpdatedAt)
	if reason != nil {
		d.Reason = *reason
	}
	return d, err
}

const getByEventSQL = `
SELECT id, event_id, device_id, platform, state, reason, updated_at FROM deliveries WHERE event_id = $1`

func (s *DeliveryStore) GetByEventID(ctx context.Context, tx velixsql.Tx, eventID string) (handlers.Delivery, bool, error) {
	var d handlers.Delivery
	var reason *string
	err := tx.QueryRow(ctx, getByEventSQL, eventID).Scan(
		&d.ID, &d.EventID, &d.DeviceID, &d.Platform, &d.State, &reason, &d.UpdatedAt)
	if errors.Is(err, velixsql.ErrNoRows) {
		return handlers.Delivery{}, false, nil
	}
	if err != nil {
		return handlers.Delivery{}, false, err
	}
	if reason != nil {
		d.Reason = *reason
	}
	return d, true, nil
}

const markSentSQL = `UPDATE deliveries SET state = 'sent', updated_at = $2 WHERE id = $1`

func (s *DeliveryStore) MarkSent(ctx context.Context, tx velixsql.Tx, id string, at time.Time) error {
	_, err := tx.Exec(ctx, markSentSQL, id, at)
	return err
}

const markFailedSQL = `UPDATE deliveries SET state = 'failed', reason = $2, updated_at = $3 WHERE id = $1`

func (s *DeliveryStore) MarkFailed(ctx context.Context, tx velixsql.Tx, id, reason string, at time.Time) error {
	_, err := tx.Exec(ctx, markFailedSQL, id, reason, at)
	return err
}

var _ handlers.DeliveryStore = (*DeliveryStore)(nil)
