package grpcserver

import (
	"context"
	"encoding/json"
	"net"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	routingv1 "github.com/velix/backend/proto/gen/go/velix/routing/v1"
	"github.com/velix/backend/services/routing/internal/handlers"
)

// ----- Minimal in-memory dependency fakes ---------------------------------

type fakeAuth struct{ acc, dev string }

func (f fakeAuth) MustFromContext(context.Context) handlers.AuthContext {
	return handlers.AuthContext{AccountID: f.acc, DeviceID: f.dev}
}

type fakeTx struct{}
type fakeTxRunner struct{}

func (*fakeTxRunner) RunSerializable(ctx context.Context, fn func(context.Context, handlers.Tx) error) error {
	return fn(ctx, fakeTx{})
}

type fakeEnvelopes struct{ rows []handlers.EnvelopeRow }

func (f *fakeEnvelopes) InsertBatch(_ context.Context, _ handlers.Tx, rows []handlers.EnvelopeRow) error {
	f.rows = append(f.rows, rows...)
	return nil
}

type fakeIdem struct{ cache map[string][]byte }

func (f *fakeIdem) Get(_ context.Context, acc, key string) ([]byte, bool, error) {
	v, ok := f.cache[acc+":"+key]
	return v, ok, nil
}
func (f *fakeIdem) Put(_ context.Context, _ handlers.Tx, acc, key string, blob []byte, _ time.Time) error {
	f.cache[acc+":"+key] = blob
	return nil
}

type fakePub struct{}

func (fakePub) Publish(context.Context, string, any) error { return nil }

type fakeClock struct{}

func (fakeClock) Now() time.Time { return time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC) }

type fakeIDs struct{ n int }

func (f *fakeIDs) NewULID() (string, error) {
	f.n++
	return "01HID00000000000000000000", nil
}

type jsonCodec struct{}

func (jsonCodec) Marshal(v any) ([]byte, error)      { return json.Marshal(v) }
func (jsonCodec) Unmarshal(d []byte, v any) error    { return json.Unmarshal(d, v) }

type silentLog struct{}

func (silentLog) Info(context.Context, string, ...any)  {}
func (silentLog) Warn(context.Context, string, ...any)  {}
func (silentLog) Error(context.Context, string, ...any) {}

type fakeCounter struct{}

func (fakeCounter) Inc()        {}
func (fakeCounter) Add(float64) {}

func newTestHandlers() *handlers.RoutingHandlers {
	return handlers.NewHandlers(handlers.Deps{
		Auth:        fakeAuth{acc: "acc1", dev: "devA"},
		TxRunner:    &fakeTxRunner{},
		Envelopes:   &fakeEnvelopes{},
		Idempotency: &fakeIdem{cache: map[string][]byte{}},
		Events:      fakePub{},
		Clock:       fakeClock{},
		IDs:         &fakeIDs{},
		Codec:       jsonCodec{},
		Log:         silentLog{},
		Metrics:     &handlers.Metrics{EnvelopesEnqueued: fakeCounter{}, PublishFailures: fakeCounter{}},
	})
}

// dialBufconn spins up a real grpc.Server over an in-memory listener and
// returns a connected RoutingService client. This exercises the generated
// server registration + the grpcserver adapter end-to-end without a network.
func dialBufconn(t *testing.T) routingv1.RoutingServiceClient {
	t.Helper()
	lis := bufconn.Listen(1024 * 1024)
	srv := grpc.NewServer()
	routingv1.RegisterRoutingServiceServer(srv, New(newTestHandlers()))
	go func() { _ = srv.Serve(lis) }()
	t.Cleanup(srv.Stop)

	conn, err := grpc.NewClient(
		"passthrough:///bufnet",
		grpc.WithContextDialer(func(ctx context.Context, _ string) (net.Conn, error) {
			return lis.DialContext(ctx)
		}),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	return routingv1.NewRoutingServiceClient(conn)
}

// ----- Tests --------------------------------------------------------------

func TestSendEnvelope_OverGRPC(t *testing.T) {
	client := dialBufconn(t)
	resp, err := client.SendEnvelope(context.Background(), &routingv1.SendEnvelopeRequest{
		IdempotencyKey: "k1",
		Recipients: []*routingv1.EnvelopeRecipient{
			{RecipientAccountId: "b", RecipientDeviceId: "bd1", Ciphertext: []byte("ct1")},
			{RecipientAccountId: "b", RecipientDeviceId: "bd2", Ciphertext: []byte("ct2")},
		},
	})
	if err != nil {
		t.Fatalf("SendEnvelope rpc: %v", err)
	}
	if len(resp.GetDelivered()) != 2 {
		t.Fatalf("delivered = %d, want 2", len(resp.GetDelivered()))
	}
	for _, d := range resp.GetDelivered() {
		if d.GetEnvelopeId() == "" || d.GetEnqueuedAt() == nil {
			t.Fatalf("incomplete delivered envelope: %+v", d)
		}
	}
}

func TestSendEnvelope_OverGRPC_ValidationError(t *testing.T) {
	client := dialBufconn(t)
	_, err := client.SendEnvelope(context.Background(), &routingv1.SendEnvelopeRequest{
		IdempotencyKey: "", // missing → InvalidArgument
		Recipients:     []*routingv1.EnvelopeRecipient{{RecipientAccountId: "b", RecipientDeviceId: "d", Ciphertext: []byte{1}}},
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("got %v, want InvalidArgument", status.Code(err))
	}
}

func TestUnimplementedRPC_OverGRPC(t *testing.T) {
	client := dialBufconn(t)
	// MarkAsRead has no handler logic yet; the generated base returns
	// Unimplemented. This proves the service registration is complete.
	_, err := client.MarkAsRead(context.Background(), &routingv1.MarkAsReadRequest{
		ConversationId: "c1", UpToMessageId: "m1",
	})
	if status.Code(err) != codes.Unimplemented {
		t.Fatalf("got %v, want Unimplemented", status.Code(err))
	}
}
