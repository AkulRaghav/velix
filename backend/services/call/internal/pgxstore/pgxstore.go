// Package pgxstore implements the call service CallStore over velixsql.
package pgxstore

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/call/internal/handlers"
)

type CallStore struct{}

func NewCallStore() *CallStore { return &CallStore{} }

const insertCallSQL = `
INSERT INTO calls (id, conversation_id, mode, security_mode, started_by, started_at, state)
VALUES ($1, $2, $3, $4, $5, $6, $7)`

func (s *CallStore) InsertCall(ctx context.Context, tx velixsql.Tx, c handlers.CallRow) error {
	_, err := tx.Exec(ctx, insertCallSQL,
		c.ID, c.ConversationID, c.Mode, c.SecurityMode, c.StartedBy, c.StartedAt, c.State)
	return err
}

const getByIDSQL = `
SELECT id, conversation_id, mode, security_mode, started_by, started_at, ended_at, state
FROM calls WHERE id = $1`

func (s *CallStore) GetByID(ctx context.Context, tx velixsql.Tx, id string) (handlers.CallRow, error) {
	var c handlers.CallRow
	err := tx.QueryRow(ctx, getByIDSQL, id).Scan(
		&c.ID, &c.ConversationID, &c.Mode, &c.SecurityMode,
		&c.StartedBy, &c.StartedAt, &c.EndedAt, &c.State)
	return c, err
}

const markEndedSQL = `UPDATE calls SET state = 'ended', ended_at = $2 WHERE id = $1`

func (s *CallStore) MarkEnded(ctx context.Context, tx velixsql.Tx, id string, endedAt time.Time) error {
	_, err := tx.Exec(ctx, markEndedSQL, id, endedAt)
	return err
}

var _ handlers.CallStore = (*CallStore)(nil)
