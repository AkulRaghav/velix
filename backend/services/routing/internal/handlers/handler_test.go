package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// ----- Fakes --------------------------------------------------------------

type fakeAuth struct{ acc, dev string }

func (f fakeAuth) MustFromContext(ctx context.Context) AuthContext {
	return AuthContext{AccountID: f.acc, DeviceID: f.dev}
}

type fakeTx struct{}

type fakeTxRunner struct{ commitErr error }

func (f *fakeTxRunner) RunSerializable(ctx context.Context, fn func(context.Context, Tx) error) error {
	if err := fn(ctx, fakeTx{}); err != nil {
		return err
	}
	return f.commitErr
}

type fakeEnvelopes struct {
	rows    []EnvelopeRow
	insertErr error
}

func (f *fakeEnvelopes) InsertBatch(ctx context.Context, tx Tx, rows []EnvelopeRow) error {
	if f.insertErr != nil {
		return f.insertErr
	}
	f.rows = append(f.rows, rows...)
	return nil
}

type fakeIdem struct {
	cache map[string][]byte
}

func newFakeIdem() *fakeIdem { return &fakeIdem{cache: map[string][]byte{}} }

func (f *fakeIdem) Get(ctx context.Context, accountID, key string) ([]byte, bool, error) {
	v, ok := f.cache[accountID+":"+key]
	return v, ok, nil
}

func (f *fakeIdem) Put(ctx context.Context, tx Tx, accountID, key string, blob []byte, expiresAt time.Time) error {
	f.cache[accountID+":"+key] = blob
	return nil
}

type fakePublisher struct {
	subjects []string
}

func (f *fakePublisher) Publish(ctx context.Context, subject string, payload any) error {
	f.subjects = append(f.subjects, subject)
	return nil
}

type fakeClock struct{ t time.Time }

func (f fakeClock) Now() time.Time { return f.t }

type fakeIDs struct{ counter atomic.Int64 }

func (f *fakeIDs) NewULID() (string, error) {
	n := f.counter.Add(1)
	return "01H" + strings.Repeat("0", 23) + idStr(n), nil
}

func idStr(n int64) string {
	const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
	if n < 0 {
		n = -n
	}
	return string(alphabet[n%32])
}

type jsonCodec struct{}

func (jsonCodec) Marshal(v any) ([]byte, error)        { return json.Marshal(v) }
func (jsonCodec) Unmarshal(data []byte, v any) error   { return json.Unmarshal(data, v) }

type silentLogger struct{}

func (silentLogger) Info(context.Context, string, ...any)  {}
func (silentLogger) Warn(context.Context, string, ...any)  {}
func (silentLogger) Error(context.Context, string, ...any) {}

type fakeCounter struct{ n atomic.Int64 }

func (c *fakeCounter) Inc()           { c.n.Add(1) }
func (c *fakeCounter) Add(d float64)  { c.n.Add(int64(d)) }

func newHandlers(t *testing.T) (*RoutingHandlers, *fakeEnvelopes, *fakeIdem, *fakePublisher) {
	t.Helper()
	envs := &fakeEnvelopes{}
	idem := newFakeIdem()
	pub := &fakePublisher{}
	h := NewHandlers(Deps{
		Auth:        fakeAuth{acc: "acc1", dev: "devA"},
		TxRunner:    &fakeTxRunner{},
		Envelopes:   envs,
		Idempotency: idem,
		Events:      pub,
		Clock:       fakeClock{t: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)},
		IDs:         &fakeIDs{},
		Codec:       jsonCodec{},
		Log:         silentLogger{},
		Metrics: &Metrics{
			EnvelopesEnqueued: &fakeCounter{},
			PublishFailures:   &fakeCounter{},
		},
	})
	return h, envs, idem, pub
}

// ----- Tests ---------------------------------------------------------------

func TestSendEnvelope_Validates(t *testing.T) {
	h, _, _, _ := newHandlers(t)
	ctx := context.Background()

	cases := []struct {
		name string
		req  *SendEnvelopeRequest
		want codes.Code
	}{
		{"nil", nil, codes.InvalidArgument},
		{"missing-key", &SendEnvelopeRequest{Recipients: []EnvelopeRecipient{{}}}, codes.InvalidArgument},
		{"empty-recipients", &SendEnvelopeRequest{IdempotencyKey: "k1"}, codes.InvalidArgument},
		{"missing-recipient-account", &SendEnvelopeRequest{
			IdempotencyKey: "k1",
			Recipients:     []EnvelopeRecipient{{Ciphertext: []byte{1}}},
		}, codes.InvalidArgument},
		{"empty-ciphertext", &SendEnvelopeRequest{
			IdempotencyKey: "k1",
			Recipients: []EnvelopeRecipient{{
				RecipientAccountID: "a", RecipientDeviceID: "d", Ciphertext: nil,
			}},
		}, codes.InvalidArgument},
		{"too-large-ciphertext", &SendEnvelopeRequest{
			IdempotencyKey: "k1",
			Recipients: []EnvelopeRecipient{{
				RecipientAccountID: "a", RecipientDeviceID: "d",
				Ciphertext: make([]byte, MaxCiphertextBytes+1),
			}},
		}, codes.InvalidArgument},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := h.SendEnvelope(ctx, c.req)
			if got := status.Code(err); got != c.want {
				t.Fatalf("got code %v, want %v (err=%v)", got, c.want, err)
			}
		})
	}
}

func TestSendEnvelope_HappyPath(t *testing.T) {
	h, envs, idem, _ := newHandlers(t)
	ctx := context.Background()
	req := &SendEnvelopeRequest{
		IdempotencyKey: "k1",
		Recipients: []EnvelopeRecipient{
			{RecipientAccountID: "b", RecipientDeviceID: "bd1", Ciphertext: []byte("ct1")},
			{RecipientAccountID: "b", RecipientDeviceID: "bd2", Ciphertext: []byte("ct2")},
		},
	}
	resp, err := h.SendEnvelope(ctx, req)
	if err != nil {
		t.Fatalf("send: %v", err)
	}
	if got, want := len(resp.Delivered), 2; got != want {
		t.Fatalf("delivered len = %d, want %d", got, want)
	}
	if got, want := len(envs.rows), 2; got != want {
		t.Fatalf("envs.rows len = %d, want %d", got, want)
	}
	for i, row := range envs.rows {
		if row.RecipientDeviceID != req.Recipients[i].RecipientDeviceID {
			t.Errorf("row[%d] device mismatch", i)
		}
	}
	// Idempotency cache populated.
	if _, ok, _ := idem.Get(ctx, "acc1", "k1"); !ok {
		t.Fatalf("idempotency cache should be populated")
	}
}

func TestSendEnvelope_IdempotencyReplay(t *testing.T) {
	h, envs, _, _ := newHandlers(t)
	ctx := context.Background()
	req := &SendEnvelopeRequest{
		IdempotencyKey: "k1",
		Recipients: []EnvelopeRecipient{
			{RecipientAccountID: "b", RecipientDeviceID: "bd1", Ciphertext: []byte("ct1")},
		},
	}
	first, err := h.SendEnvelope(ctx, req)
	if err != nil {
		t.Fatalf("first send: %v", err)
	}
	// Replay with same key.
	second, err := h.SendEnvelope(ctx, req)
	if err != nil {
		t.Fatalf("second send: %v", err)
	}
	if first.Delivered[0].EnvelopeID != second.Delivered[0].EnvelopeID {
		t.Fatalf("idempotent replay must return cached envelope id")
	}
	// No additional row inserted on replay.
	if got, want := len(envs.rows), 1; got != want {
		t.Fatalf("envs.rows = %d after replay; want %d", got, want)
	}
}

func TestSendEnvelope_TooManyRecipients(t *testing.T) {
	h, _, _, _ := newHandlers(t)
	ctx := context.Background()
	rec := make([]EnvelopeRecipient, MaxRecipientsPerSend+1)
	for i := range rec {
		rec[i] = EnvelopeRecipient{
			RecipientAccountID: "b",
			RecipientDeviceID:  "d" + idStr(int64(i)),
			Ciphertext:         []byte{1},
		}
	}
	_, err := h.SendEnvelope(ctx, &SendEnvelopeRequest{IdempotencyKey: "k1", Recipients: rec})
	if got := status.Code(err); got != codes.InvalidArgument {
		t.Fatalf("got %v, want InvalidArgument", got)
	}
}

func TestSendEnvelope_DBFailure(t *testing.T) {
	h, envs, _, _ := newHandlers(t)
	envs.insertErr = errors.New("connection refused")
	_, err := h.SendEnvelope(context.Background(), &SendEnvelopeRequest{
		IdempotencyKey: "k1",
		Recipients: []EnvelopeRecipient{
			{RecipientAccountID: "b", RecipientDeviceID: "bd1", Ciphertext: []byte{1}},
		},
	})
	if got := status.Code(err); got != codes.Internal {
		t.Fatalf("got %v, want Internal", got)
	}
}
