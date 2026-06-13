// Package velixsql is the database seam.
//
// We do NOT use database/sql directly in services. Each service depends on
// this package's interfaces, and main.go wires a pgx-backed implementation.
//
// Hard rules:
//   - All writes through transactions.
//   - All transactions tagged with the request id (statement_timeout +
//     application_name).
//   - All queries parameterized; never string-concatenate SQL.
//   - All migrations through goose (per service migrations dir).
package velixsql

import (
	"context"
	"errors"
	"time"
)

// Conn is an abstract connection used by handlers. Production wires pgx.
type Conn interface {
	Exec(ctx context.Context, sql string, args ...any) (CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) Row
}

// CommandTag carries the affected-row count.
type CommandTag interface {
	RowsAffected() int64
}

// Rows is the multi-row scan iterator.
type Rows interface {
	Next() bool
	Scan(dest ...any) error
	Err() error
	Close()
}

// Row is the single-row scan.
type Row interface {
	Scan(dest ...any) error
}

// TxRunner runs a function inside a transaction with the given isolation level.
type TxRunner interface {
	Run(ctx context.Context, isolation Isolation, fn func(ctx context.Context, tx Tx) error) error
}

// Tx is the transactional connection passed to RunSerializable callbacks.
type Tx interface {
	Conn
}

// Isolation level enum.
type Isolation int

const (
	IsoReadCommitted Isolation = iota
	IsoRepeatableRead
	IsoSerializable
)

// Common errors. Wrap with velixerr at call sites.
var (
	ErrNoRows           = errors.New("velixsql: no rows")
	ErrTxAborted        = errors.New("velixsql: transaction aborted")
	ErrUniqueViolation  = errors.New("velixsql: unique violation")
	ErrForeignKeyMissing = errors.New("velixsql: foreign key missing")
)

// HealthCheck is the readiness probe the gateway calls before sending traffic.
type HealthCheck interface {
	Ping(ctx context.Context) error
}

// PoolStats are exposed via /metrics.
type PoolStats struct {
	Acquired    int32
	Idle        int32
	Total       int32
	WaitDuration time.Duration
}

// PoolStatter exposes pool statistics for instrumentation.
type PoolStatter interface {
	Stats() PoolStats
}
