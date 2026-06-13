package handlers

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixsql"
)

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

func (f *fakeTxRunner) Run(ctx context.Context, _ velixsql.Isolation, fn func(context.Context, velixsql.Tx) error) error {
	return fn(ctx, fakeTx{})
}

type fakeMedia struct{ rows map[string]MediaRow }

func newFakeMedia() *fakeMedia { return &fakeMedia{rows: map[string]MediaRow{}} }

func (f *fakeMedia) InsertPending(ctx context.Context, tx velixsql.Tx, m MediaRow) error {
	if _, ok := f.rows[m.ID]; ok {
		return errors.New("dup")
	}
	f.rows[m.ID] = m
	return nil
}
func (f *fakeMedia) GetByID(ctx context.Context, tx velixsql.Tx, id string) (MediaRow, error) {
	m, ok := f.rows[id]
	if !ok {
		return MediaRow{}, errors.New("not found")
	}
	return m, nil
}
func (f *fakeMedia) MarkUploaded(ctx context.Context, tx velixsql.Tx, id string, b3 []byte, at time.Time) error {
	m := f.rows[id]
	m.State = "uploaded"
	m.CiphertextBlake3 = b3
	m.FinalizedAt = &at
	f.rows[id] = m
	return nil
}
func (f *fakeMedia) MarkDeleted(ctx context.Context, tx velixsql.Tx, id string, at time.Time) error {
	m := f.rows[id]
	m.State = "deleted"
	f.rows[id] = m
	return nil
}

type fakeStorage struct {
	uploadCalls int
	objects     map[string]int64
}

func newFakeStorage() *fakeStorage { return &fakeStorage{objects: map[string]int64{}} }

func (f *fakeStorage) PresignPut(ctx context.Context, key string, sizeBytes int64, ttl time.Duration) (string, map[string]string, error) {
	f.uploadCalls++
	return "https://r2.example/" + key, map[string]string{"x-amz-content-sha256": "..."}, nil
}
func (f *fakeStorage) PresignGet(ctx context.Context, key string, ttl time.Duration) (string, error) {
	return "https://r2.example/" + key, nil
}
func (f *fakeStorage) HeadObject(ctx context.Context, key string) (int64, bool, error) {
	v, ok := f.objects[key]
	return v, ok, nil
}
func (f *fakeStorage) DeleteObject(ctx context.Context, key string) error {
	delete(f.objects, key)
	return nil
}

type fakePub struct{}

func (fakePub) Publish(context.Context, string, []byte) error      { return nil }
func (fakePub) PublishAsync(context.Context, string, []byte) error { return nil }

type fakeClock struct{ t time.Time }

func (f fakeClock) Now() time.Time { return f.t }

type fakeIDs struct{ counter atomic.Int64 }

func (f *fakeIDs) NewULID() (string, error) {
	n := f.counter.Add(1)
	return "01HMEDIA000000000000000" + string("0123456789ABCDEFGHJKMNPQRSTVWXYZ"[n%32]), nil
}

type fakeCounter struct{}

func (fakeCounter) Inc()        {}
func (fakeCounter) Add(float64) {}

func newHandlers(t *testing.T) (*MediaHandlers, *fakeMedia, *fakeStorage) {
	t.Helper()
	media := newFakeMedia()
	storage := newFakeStorage()
	return &MediaHandlers{
		tx: &fakeTxRunner{}, media: media, storage: storage, events: fakePub{},
		clock: fakeClock{t: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)},
		ids:   &fakeIDs{},
		log:   nil,
		metrics: &Metrics{
			UploadsCreated: fakeCounter{}, UploadsFinalized: fakeCounter{},
			DownloadsIssued: fakeCounter{}, Deleted: fakeCounter{},
		},
	}, media, storage
}

func ctxWithUser() context.Context {
	return velixctx.WithPrincipal(context.Background(), "alice", "dev1")
}

func TestCreateUpload_HappyPath(t *testing.T) {
	h, media, storage := newHandlers(t)
	resp, err := h.CreateUpload(ctxWithUser(), &CreateUploadRequest{
		IdempotencyKey: "k1", ContentTypeClass: "image", SizeBytes: 1024,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if resp.UploadURL == "" || resp.MediaID == "" {
		t.Fatalf("missing fields in response: %+v", resp)
	}
	if storage.uploadCalls != 1 {
		t.Fatalf("expected 1 storage call; got %d", storage.uploadCalls)
	}
	if len(media.rows) != 1 {
		t.Fatalf("expected 1 media row; got %d", len(media.rows))
	}
}

func TestCreateUpload_RejectsBadSize(t *testing.T) {
	h, _, _ := newHandlers(t)
	_, err := h.CreateUpload(ctxWithUser(), &CreateUploadRequest{
		IdempotencyKey: "k1", ContentTypeClass: "image", SizeBytes: 200 * 1024 * 1024,
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestCreateUpload_RejectsBadContentClass(t *testing.T) {
	h, _, _ := newHandlers(t)
	_, err := h.CreateUpload(ctxWithUser(), &CreateUploadRequest{
		IdempotencyKey: "k1", ContentTypeClass: "executable", SizeBytes: 100,
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestFinalize_RejectsSizeMismatch(t *testing.T) {
	h, _, storage := newHandlers(t)
	c, err := h.CreateUpload(ctxWithUser(), &CreateUploadRequest{
		IdempotencyKey: "k1", ContentTypeClass: "image", SizeBytes: 1024,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	storage.objects[objectKey("alice", c.MediaID)] = 999 // wrong size
	_, err = h.FinalizeUpload(ctxWithUser(), &FinalizeUploadRequest{
		IdempotencyKey: "f1", MediaID: c.MediaID, CiphertextBlake3: make([]byte, 32),
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestDelete_OnlyByOwner(t *testing.T) {
	h, _, _ := newHandlers(t)
	c, _ := h.CreateUpload(ctxWithUser(), &CreateUploadRequest{
		IdempotencyKey: "k1", ContentTypeClass: "image", SizeBytes: 1024,
	})
	intruder := velixctx.WithPrincipal(context.Background(), "mallory", "dev2")
	_, err := h.DeleteMedia(intruder, &DeleteMediaRequest{
		IdempotencyKey: "del1", MediaID: c.MediaID,
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeForbidden {
		t.Fatalf("got %q, want permission_denied", got)
	}
}
