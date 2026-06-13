package handlers

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

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

type fakeDeliveries struct {
	mu       sync.Mutex
	byID     map[string]Delivery
	byEvent  map[string]Delivery
}

func newFakeDeliveries() *fakeDeliveries {
	return &fakeDeliveries{byID: map[string]Delivery{}, byEvent: map[string]Delivery{}}
}

func (f *fakeDeliveries) Insert(ctx context.Context, tx velixsql.Tx, d Delivery) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.byID[d.ID] = d
	f.byEvent[d.EventID] = d
	return nil
}
func (f *fakeDeliveries) GetByID(ctx context.Context, tx velixsql.Tx, id string) (Delivery, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	d, ok := f.byID[id]
	if !ok {
		return Delivery{}, errors.New("not found")
	}
	return d, nil
}
func (f *fakeDeliveries) GetByEventID(ctx context.Context, tx velixsql.Tx, eventID string) (Delivery, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	d, ok := f.byEvent[eventID]
	return d, ok, nil
}
func (f *fakeDeliveries) MarkSent(ctx context.Context, tx velixsql.Tx, id string, at time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	d := f.byID[id]
	d.State = "sent"
	f.byID[id] = d
	return nil
}
func (f *fakeDeliveries) MarkFailed(ctx context.Context, tx velixsql.Tx, id, reason string, at time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	d := f.byID[id]
	d.State = "failed"
	d.Reason = reason
	f.byID[id] = d
	return nil
}

type fakeTokens struct {
	platform string
	err      error
}

func (f fakeTokens) ForDevice(ctx context.Context, deviceID string) (string, []byte, []byte, error) {
	if f.err != nil {
		return "", nil, nil, f.err
	}
	return f.platform, []byte("token"), nil, nil
}

type fakeSender struct{ err error }

func (f fakeSender) Send(context.Context, []byte, []byte, time.Time, string) error { return f.err }

type fakePub struct{}

func (fakePub) Publish(context.Context, string, []byte) error      { return nil }
func (fakePub) PublishAsync(context.Context, string, []byte) error { return nil }

type fakeClock struct{ t time.Time }

func (f fakeClock) Now() time.Time { return f.t }

type fakeIDs struct{ counter atomic.Int64 }

func (f *fakeIDs) NewULID() (string, error) {
	n := f.counter.Add(1)
	return "01HNOTIF0000000000000000" + string("0123456789ABCDEFGHJKMNPQRSTVWXYZ"[n%32]), nil
}

type fakeCounter struct{}

func (fakeCounter) Inc()        {}
func (fakeCounter) Add(float64) {}

func newHandlers(platform string, sendErr error) (*NotifierHandlers, *fakeDeliveries) {
	delivs := newFakeDeliveries()
	return &NotifierHandlers{
		tx: &fakeTxRunner{}, delivs: delivs,
		apns: fakeSender{err: sendErr}, fcm: fakeSender{err: sendErr}, webpush: fakeSender{err: sendErr},
		tokens: fakeTokens{platform: platform},
		events: fakePub{},
		clock:  fakeClock{t: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)},
		ids:    &fakeIDs{}, log: nil,
		metrics: &Metrics{PushesEnqueued: fakeCounter{}, PushesSent: fakeCounter{}, PushesFailed: fakeCounter{}},
	}, delivs
}

func futureTime() time.Time { return time.Date(2026, 5, 28, 13, 0, 0, 0, time.UTC) }

// ----- Tests --------------------------------------------------------------

func TestEnqueuePush_HappyPath(t *testing.T) {
	h, delivs := newHandlers("apns", nil)
	resp, err := h.EnqueuePush(context.Background(), &EnqueuePushRequest{
		EventID: "evt1", DeviceID: "dev1", EncryptedPayload: []byte("blob"), ExpiresAt: futureTime(),
	})
	if err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	if resp.DeliveryID == "" {
		t.Fatal("delivery id must be set")
	}
	if len(delivs.byID) != 1 {
		t.Fatalf("expected 1 delivery; got %d", len(delivs.byID))
	}
}

func TestEnqueuePush_RejectsExpiredPayload(t *testing.T) {
	h, _ := newHandlers("apns", nil)
	_, err := h.EnqueuePush(context.Background(), &EnqueuePushRequest{
		EventID: "evt1", DeviceID: "dev1", EncryptedPayload: []byte("blob"),
		ExpiresAt: time.Date(2026, 5, 28, 11, 0, 0, 0, time.UTC), // past
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestEnqueuePush_RejectsOversizePayload(t *testing.T) {
	h, _ := newHandlers("apns", nil)
	_, err := h.EnqueuePush(context.Background(), &EnqueuePushRequest{
		EventID: "evt1", DeviceID: "dev1",
		EncryptedPayload: make([]byte, MaxPayloadBytes+1), ExpiresAt: futureTime(),
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestEnqueuePush_IdempotentByEventID(t *testing.T) {
	h, _ := newHandlers("apns", nil)
	first, err := h.EnqueuePush(context.Background(), &EnqueuePushRequest{
		EventID: "evt1", DeviceID: "dev1", EncryptedPayload: []byte("blob"), ExpiresAt: futureTime(),
	})
	if err != nil {
		t.Fatalf("first: %v", err)
	}
	second, err := h.EnqueuePush(context.Background(), &EnqueuePushRequest{
		EventID: "evt1", DeviceID: "dev1", EncryptedPayload: []byte("blob"), ExpiresAt: futureTime(),
	})
	if err != nil {
		t.Fatalf("second: %v", err)
	}
	if first.DeliveryID != second.DeliveryID {
		t.Fatalf("idempotent replay must return the same delivery id")
	}
}

func TestGetPushStatus_NotFound(t *testing.T) {
	h, _ := newHandlers("apns", nil)
	_, err := h.GetPushStatus(context.Background(), &GetPushStatusRequest{DeliveryID: "nope"})
	if got := velixerr.CodeOf(err); got != velixerr.CodeNotFound {
		t.Fatalf("got %q, want not_found", got)
	}
}
