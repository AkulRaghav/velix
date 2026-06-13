package grpcserver

import (
	"context"
	"net"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	mediav1 "github.com/velix/backend/proto/gen/go/velix/media/v1"
	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/services/media/internal/handlers"
)

// ----- In-memory fakes ----------------------------------------------------

type memTx struct{}

func (memTx) Exec(context.Context, string, ...any) (velixsql.CommandTag, error) { return memTag{}, nil }
func (memTx) Query(context.Context, string, ...any) (velixsql.Rows, error) {
	return nil, velixsql.ErrNoRows
}
func (memTx) QueryRow(context.Context, string, ...any) velixsql.Row { return memRow{} }

type memTag struct{}

func (memTag) RowsAffected() int64 { return 0 }

type memRow struct{}

func (memRow) Scan(...any) error { return velixsql.ErrNoRows }

type memTxRunner struct{}

func (memTxRunner) Run(ctx context.Context, _ velixsql.Isolation, fn func(context.Context, velixsql.Tx) error) error {
	return fn(ctx, memTx{})
}

type memMedia struct{ rows map[string]handlers.MediaRow }

func (m *memMedia) InsertPending(_ context.Context, _ velixsql.Tx, row handlers.MediaRow) error {
	m.rows[row.ID] = row
	return nil
}
func (m *memMedia) GetByID(_ context.Context, _ velixsql.Tx, id string) (handlers.MediaRow, error) {
	r, ok := m.rows[id]
	if !ok {
		return handlers.MediaRow{}, velixsql.ErrNoRows
	}
	return r, nil
}
func (m *memMedia) MarkUploaded(context.Context, velixsql.Tx, string, []byte, time.Time) error {
	return nil
}
func (m *memMedia) MarkDeleted(context.Context, velixsql.Tx, string, time.Time) error { return nil }

// okStorage returns a usable presigned URL so CreateUpload succeeds.
type okStorage struct{}

func (okStorage) PresignPut(context.Context, string, int64, time.Duration) (string, map[string]string, error) {
	return "https://r2.example/k", map[string]string{"h": "v"}, nil
}
func (okStorage) PresignGet(context.Context, string, time.Duration) (string, error) {
	return "https://r2.example/k", nil
}
func (okStorage) HeadObject(context.Context, string) (int64, bool, error) { return 0, false, nil }
func (okStorage) DeleteObject(context.Context, string) error             { return nil }

type fakePub struct{}

func (fakePub) Publish(context.Context, string, []byte) error      { return nil }
func (fakePub) PublishAsync(context.Context, string, []byte) error { return nil }

type sysClock struct{}

func (sysClock) Now() time.Time { return time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC) }

type seqIDs struct{ n int }

func (s *seqIDs) NewULID() (string, error) { s.n++; return "01HMEDIA00000000000000000", nil }

type fakeCounter struct{}

func (fakeCounter) Inc()        {}
func (fakeCounter) Add(float64) {}

func newTestHandlers() *handlers.MediaHandlers {
	return handlers.NewHandlers(handlers.Deps{
		TxRunner: memTxRunner{},
		Media:    &memMedia{rows: map[string]handlers.MediaRow{}},
		Storage:  okStorage{},
		Events:   fakePub{},
		Clock:    sysClock{},
		IDs:      &seqIDs{},
		Log:      nil,
		Metrics: &handlers.Metrics{
			UploadsCreated: fakeCounter{}, UploadsFinalized: fakeCounter{},
			DownloadsIssued: fakeCounter{}, Deleted: fakeCounter{},
		},
	})
}

// principalInterceptor injects a test principal so handlers that require one
// (CreateUpload) succeed over the wire.
func principalInterceptor(ctx context.Context, req any, _ *grpc.UnaryServerInfo, h grpc.UnaryHandler) (any, error) {
	return h(velixctx.WithPrincipal(ctx, "alice", "dev1"), req)
}

func dialBufconn(t *testing.T) mediav1.MediaServiceClient {
	t.Helper()
	lis := bufconn.Listen(1024 * 1024)
	srv := grpc.NewServer(grpc.UnaryInterceptor(principalInterceptor))
	mediav1.RegisterMediaServiceServer(srv, New(newTestHandlers()))
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
	return mediav1.NewMediaServiceClient(conn)
}

// ----- Tests --------------------------------------------------------------

func TestCreateUpload_OverGRPC(t *testing.T) {
	client := dialBufconn(t)
	resp, err := client.CreateUpload(context.Background(), &mediav1.CreateUploadRequest{
		IdempotencyKey: "k1", ContentTypeClass: "image", SizeBytes: 2048,
	})
	if err != nil {
		t.Fatalf("CreateUpload rpc: %v", err)
	}
	if resp.GetMediaId() == "" || resp.GetUploadUrl() == "" {
		t.Fatalf("incomplete response: %+v", resp)
	}
}

func TestCreateUpload_OverGRPC_BadContentClass(t *testing.T) {
	client := dialBufconn(t)
	_, err := client.CreateUpload(context.Background(), &mediav1.CreateUploadRequest{
		IdempotencyKey: "k1", ContentTypeClass: "binary", SizeBytes: 10,
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("got %v, want InvalidArgument", status.Code(err))
	}
}
