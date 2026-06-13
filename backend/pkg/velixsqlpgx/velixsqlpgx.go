// Package velixsqlpgx is the pgx-backed implementation of the velixsql seam.
//
// It adapts *pgxpool.Pool to velixsql.TxRunner / velixsql.Conn so service
// handlers depend only on the velixsql interfaces while main.go wires this
// concrete implementation.
package velixsqlpgx

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/velix/backend/pkg/velixsql"
)

// Pool adapts a pgxpool.Pool to velixsql.TxRunner + velixsql.Conn + health.
type Pool struct {
	pool *pgxpool.Pool
}

// NewPool wraps an established pgxpool.Pool.
func NewPool(pool *pgxpool.Pool) *Pool { return &Pool{pool: pool} }

// Connect opens a new pool from a DSN and returns the adapter.
func Connect(ctx context.Context, dsn string) (*Pool, error) {
	p, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, err
	}
	if err := p.Ping(ctx); err != nil {
		p.Close()
		return nil, err
	}
	return &Pool{pool: p}, nil
}

// Close releases the underlying pool.
func (p *Pool) Close() { p.pool.Close() }

// Ping satisfies velixsql.HealthCheck.
func (p *Pool) Ping(ctx context.Context) error { return p.pool.Ping(ctx) }

// Run implements velixsql.TxRunner.
func (p *Pool) Run(
	ctx context.Context,
	iso velixsql.Isolation,
	fn func(ctx context.Context, tx velixsql.Tx) error,
) error {
	tx, err := p.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: isoLevel(iso)})
	if err != nil {
		return err
	}
	if err := fn(ctx, &txConn{tx: tx}); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	return nil
}

// ----- Non-transactional Conn (delegates to the pool) ---------------------

func (p *Pool) Exec(ctx context.Context, sql string, args ...any) (velixsql.CommandTag, error) {
	tag, err := p.pool.Exec(ctx, sql, args...)
	return commandTag{tag.RowsAffected()}, mapErr(err)
}

func (p *Pool) Query(ctx context.Context, sql string, args ...any) (velixsql.Rows, error) {
	rows, err := p.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, mapErr(err)
	}
	return &rowsAdapter{rows: rows}, nil
}

func (p *Pool) QueryRow(ctx context.Context, sql string, args ...any) velixsql.Row {
	return rowAdapter{row: p.pool.QueryRow(ctx, sql, args...)}
}

func isoLevel(iso velixsql.Isolation) pgx.TxIsoLevel {
	switch iso {
	case velixsql.IsoSerializable:
		return pgx.Serializable
	case velixsql.IsoRepeatableRead:
		return pgx.RepeatableRead
	default:
		return pgx.ReadCommitted
	}
}

// mapErr translates pgx sentinel errors to velixsql sentinels.
func mapErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return velixsql.ErrNoRows
	}
	return err
}
