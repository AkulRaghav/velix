package velixsqlpgx

import (
	"context"

	"github.com/jackc/pgx/v5"

	"github.com/velix/backend/pkg/velixsql"
)

// ----- commandTag ---------------------------------------------------------

type commandTag struct{ n int64 }

func (c commandTag) RowsAffected() int64 { return c.n }

// ----- txConn: velixsql.Tx over a pgx.Tx ----------------------------------

type txConn struct{ tx pgx.Tx }

func (t *txConn) Exec(ctx context.Context, sql string, args ...any) (velixsql.CommandTag, error) {
	tag, err := t.tx.Exec(ctx, sql, args...)
	return commandTag{tag.RowsAffected()}, mapErr(err)
}

func (t *txConn) Query(ctx context.Context, sql string, args ...any) (velixsql.Rows, error) {
	rows, err := t.tx.Query(ctx, sql, args...)
	if err != nil {
		return nil, mapErr(err)
	}
	return &rowsAdapter{rows: rows}, nil
}

func (t *txConn) QueryRow(ctx context.Context, sql string, args ...any) velixsql.Row {
	return rowAdapter{row: t.tx.QueryRow(ctx, sql, args...)}
}

// ----- rows / row ---------------------------------------------------------

type rowsAdapter struct{ rows pgx.Rows }

func (r *rowsAdapter) Next() bool              { return r.rows.Next() }
func (r *rowsAdapter) Scan(dest ...any) error  { return r.rows.Scan(dest...) }
func (r *rowsAdapter) Err() error              { return mapErr(r.rows.Err()) }
func (r *rowsAdapter) Close()                  { r.rows.Close() }

type rowAdapter struct{ row pgx.Row }

func (r rowAdapter) Scan(dest ...any) error { return mapErr(r.row.Scan(dest...)) }

// Compile-time interface checks.
var (
	_ velixsql.TxRunner    = (*Pool)(nil)
	_ velixsql.Conn        = (*Pool)(nil)
	_ velixsql.HealthCheck = (*Pool)(nil)
	_ velixsql.Tx          = (*txConn)(nil)
	_ velixsql.Rows        = (*rowsAdapter)(nil)
	_ velixsql.Row         = rowAdapter{}
)
