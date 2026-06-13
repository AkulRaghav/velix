// Package pgxstore provides pgx-backed implementations of the routing
// handler storage interfaces (EnvelopeStore, IdempotencyStore, TxRunner).
//
// The transaction seam: RunSerializable opens a pgx.Tx at SERIALIZABLE
// isolation, runs the callback, and commits. The callback receives the tx as
// the handler's opaque `Tx` value; the stores type-assert it back to pgx.Tx.
package pgxstore

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/velix/backend/services/routing/internal/handlers"
)

// New builds the store trio from a live pgxpool.Pool.
func New(pool *pgxpool.Pool) (handlers.TxRunner, handlers.EnvelopeStore, handlers.IdempotencyStore) {
	return &TxRunner{pool: pool},
		&EnvelopeStore{},
		&IdempotencyStore{pool: pool}
}

// ----- TxRunner -----------------------------------------------------------

// TxRunner runs callbacks inside a SERIALIZABLE pgx transaction.
type TxRunner struct {
	pool *pgxpool.Pool
}

func NewTxRunner(pool *pgxpool.Pool) *TxRunner { return &TxRunner{pool: pool} }

func (r *TxRunner) RunSerializable(
	ctx context.Context,
	fn func(context.Context, handlers.Tx) error,
) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	if err := fn(ctx, tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		_ = tx.Rollback(ctx)
		return fmt.Errorf("commit: %w", err)
	}
	return nil
}

// txFromHandler recovers the pgx.Tx the TxRunner placed into the callback.
func txFromHandler(t handlers.Tx) (pgx.Tx, error) {
	tx, ok := t.(pgx.Tx)
	if !ok {
		return nil, errors.New("pgxstore: handler Tx is not a pgx.Tx")
	}
	return tx, nil
}

// ----- EnvelopeStore ------------------------------------------------------

// EnvelopeStore writes message_envelope rows.
type EnvelopeStore struct{}

func NewEnvelopeStore() *EnvelopeStore { return &EnvelopeStore{} }

const insertEnvelopeSQL = `
INSERT INTO message_envelope
  (id, recipient_account_id, recipient_device_id, ciphertext, enqueued_at, ttl_at)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (id) DO NOTHING`

func (s *EnvelopeStore) InsertBatch(
	ctx context.Context,
	t handlers.Tx,
	rows []handlers.EnvelopeRow,
) error {
	tx, err := txFromHandler(t)
	if err != nil {
		return err
	}
	batch := &pgx.Batch{}
	for _, row := range rows {
		batch.Queue(insertEnvelopeSQL,
			row.ID, row.RecipientAccountID, row.RecipientDeviceID,
			row.Ciphertext, row.EnqueuedAt, row.TTLAt)
	}
	br := tx.SendBatch(ctx, batch)
	defer func() { _ = br.Close() }()
	for range rows {
		if _, err := br.Exec(); err != nil {
			return fmt.Errorf("insert envelope: %w", err)
		}
	}
	return nil
}

// ----- IdempotencyStore ---------------------------------------------------

// IdempotencyStore reads/writes idempotency_keys. Reads happen outside the
// transaction (read-through); writes happen inside the handler's tx.
type IdempotencyStore struct {
	// pool is used for the read path (Get), which runs before the tx opens.
	pool *pgxpool.Pool
}

func NewIdempotencyStore(pool *pgxpool.Pool) *IdempotencyStore {
	return &IdempotencyStore{pool: pool}
}

const getIdemSQL = `
SELECT response_blob FROM idempotency_keys
WHERE account_id = $1 AND key = $2 AND expires_at > now()`

func (s *IdempotencyStore) Get(
	ctx context.Context,
	accountID, key string,
) ([]byte, bool, error) {
	if s.pool == nil {
		return nil, false, nil
	}
	var blob []byte
	err := s.pool.QueryRow(ctx, getIdemSQL, accountID, key).Scan(&blob)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("idem get: %w", err)
	}
	return blob, true, nil
}

const putIdemSQL = `
INSERT INTO idempotency_keys (account_id, key, response_blob, expires_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (account_id, key) DO NOTHING`

func (s *IdempotencyStore) Put(
	ctx context.Context,
	t handlers.Tx,
	accountID, key string,
	blob []byte,
	expiresAt time.Time,
) error {
	tx, err := txFromHandler(t)
	if err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, putIdemSQL, accountID, key, blob, expiresAt); err != nil {
		return fmt.Errorf("idem put: %w", err)
	}
	return nil
}
