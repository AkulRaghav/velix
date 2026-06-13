package handlers

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixsql"
)

// ----- Fakes --------------------------------------------------------------

type fakeTx struct{}

func (fakeTx) Exec(context.Context, string, ...any) (velixsql.CommandTag, error) {
	return fakeCommandTag{}, nil
}
func (fakeTx) Query(context.Context, string, ...any) (velixsql.Rows, error) {
	return nil, velixsql.ErrNoRows
}
func (fakeTx) QueryRow(context.Context, string, ...any) velixsql.Row { return fakeRow{} }

type fakeCommandTag struct{}

func (fakeCommandTag) RowsAffected() int64 { return 0 }

type fakeRow struct{}

func (fakeRow) Scan(...any) error { return velixsql.ErrNoRows }

type fakeTxRunner struct{}

func (*fakeTxRunner) Run(ctx context.Context, _ velixsql.Isolation, fn func(context.Context, velixsql.Tx) error) error {
	return fn(ctx, fakeTx{})
}

type fakeCalls struct {
	rows map[string]CallRow
}

func newFakeCalls() *fakeCalls { return &fakeCalls{rows: map[string]CallRow{}} }

func (f *fakeCalls) InsertCall(ctx context.Context, tx velixsql.Tx, c CallRow) error {
	f.rows[c.ID] = c
	return nil
}
func (f *fakeCalls) GetByID(ctx context.Context, tx velixsql.Tx, id string) (CallRow, error) {
	c, ok := f.rows[id]
	if !ok {
		return CallRow{}, velixsql.ErrNoRows
	}
	return c, nil
}
func (f *fakeCalls) MarkEnded(ctx context.Context, tx velixsql.Tx, id string, endedAt time.Time) error {
	c := f.rows[id]
	c.State = "ended"
	c.EndedAt = &endedAt
	f.rows[id] = c
	return nil
}

type fakeLiveKit struct {
	rooms       map[string]bool
	issueErr    error
	tokensIssued int
}

func newFakeLiveKit() *fakeLiveKit { return &fakeLiveKit{rooms: map[string]bool{}} }

func (f *fakeLiveKit) CreateRoom(ctx context.Context, name string) error {
	f.rooms[name] = true
	return nil
}
func (f *fakeLiveKit) IssueToken(ctx context.Context, room, identity string, e2ee bool, ttl time.Duration) (string, error) {
	if f.issueErr != nil {
		return "", f.issueErr
	}
	f.tokensIssued++
	return "livekit-token-" + room, nil
}
func (f *fakeLiveKit) DeleteRoom(ctx context.Context, name string) error {
	delete(f.rooms, name)
	return nil
}

type fakePub struct{ subjects []string }

func (f *fakePub) Publish(_ context.Context, subject string, _ []byte) error {
	f.subjects = append(f.subjects, subject)
	return nil
}
func (f *fakePub) PublishAsync(context.Context, string, []byte) error { return nil }

type fakeClock struct{ t time.Time }

func (f fakeClock) Now() time.Time { return f.t }

type fakeIDs struct{ counter atomic.Int64 }

func (f *fakeIDs) NewULID() (string, error) {
	n := f.counter.Add(1)
	return "01HCALL00000000000000000" + string("0123456789ABCDEFGHJKMNPQRSTVWXYZ"[n%32]), nil
}

type fakeCounter struct{}

func (fakeCounter) Inc()        {}
func (fakeCounter) Add(float64) {}

func newHandlers() (*CallHandlers, *fakeCalls, *fakeLiveKit, *fakePub) {
	calls := newFakeCalls()
	lk := newFakeLiveKit()
	pub := &fakePub{}
	return &CallHandlers{
		tx: &fakeTxRunner{}, calls: calls, livekit: lk, events: pub,
		clock: fakeClock{t: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)},
		ids:   &fakeIDs{}, log: nil,
		metrics: &Metrics{CallsCreated: fakeCounter{}, CallsEnded: fakeCounter{}, TokensIssued: fakeCounter{}},
	}, calls, lk, pub
}

func userCtx() context.Context {
	return velixctx.WithPrincipal(context.Background(), "acc1", "dev1")
}

// ----- Tests --------------------------------------------------------------

func TestCreateCall_HappyPath(t *testing.T) {
	h, calls, lk, _ := newHandlers()
	resp, err := h.CreateCall(userCtx(), &CreateCallRequest{
		IdempotencyKey: "k1", ConversationID: "conv1", Mode: "video",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if resp.CallID == "" || resp.LiveKitToken == "" {
		t.Fatalf("missing fields: %+v", resp)
	}
	if len(calls.rows) != 1 {
		t.Fatalf("expected 1 call row; got %d", len(calls.rows))
	}
	if len(lk.rooms) != 1 {
		t.Fatalf("expected 1 room; got %d", len(lk.rooms))
	}
}

func TestCreateCall_DefaultsToE2EE(t *testing.T) {
	h, calls, _, _ := newHandlers()
	resp, err := h.CreateCall(userCtx(), &CreateCallRequest{
		IdempotencyKey: "k1", ConversationID: "conv1", Mode: "audio",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if calls.rows[resp.CallID].SecurityMode != "e2ee" {
		t.Fatalf("expected default e2ee; got %q", calls.rows[resp.CallID].SecurityMode)
	}
}

func TestCreateCall_RejectsBadMode(t *testing.T) {
	h, _, _, _ := newHandlers()
	_, err := h.CreateCall(userCtx(), &CreateCallRequest{
		IdempotencyKey: "k1", ConversationID: "conv1", Mode: "telepathy",
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestCreateCall_RequiresPrincipal(t *testing.T) {
	h, _, _, _ := newHandlers()
	_, err := h.CreateCall(context.Background(), &CreateCallRequest{
		IdempotencyKey: "k1", ConversationID: "conv1", Mode: "video",
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeUnauthorized {
		t.Fatalf("got %q, want unauthenticated", got)
	}
}

func TestEndCall_Idempotent(t *testing.T) {
	h, _, _, _ := newHandlers()
	c, err := h.CreateCall(userCtx(), &CreateCallRequest{
		IdempotencyKey: "k1", ConversationID: "conv1", Mode: "video",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := h.EndCall(userCtx(), &EndCallRequest{CallID: c.CallID}); err != nil {
		t.Fatalf("end 1: %v", err)
	}
	// Second end is a no-op, not an error.
	if _, err := h.EndCall(userCtx(), &EndCallRequest{CallID: c.CallID}); err != nil {
		t.Fatalf("end 2 (idempotent) should not error: %v", err)
	}
}

func TestIssueCallToken_RejectsEndedCall(t *testing.T) {
	h, _, _, _ := newHandlers()
	c, _ := h.CreateCall(userCtx(), &CreateCallRequest{
		IdempotencyKey: "k1", ConversationID: "conv1", Mode: "video",
	})
	_, _ = h.EndCall(userCtx(), &EndCallRequest{CallID: c.CallID})
	_, err := h.IssueCallToken(userCtx(), &IssueCallTokenRequest{CallID: c.CallID})
	if got := velixerr.CodeOf(err); got != velixerr.CodeNotFound {
		t.Fatalf("got %q, want not_found", got)
	}
}

func TestRejectCall_PublishesEvent(t *testing.T) {
	h, _, _, pub := newHandlers()
	if _, err := h.RejectCall(userCtx(), &RejectCallRequest{CallID: "call1", Reason: "busy"}); err != nil {
		t.Fatalf("reject: %v", err)
	}
	if len(pub.subjects) != 1 {
		t.Fatalf("expected 1 published event; got %d", len(pub.subjects))
	}
}
