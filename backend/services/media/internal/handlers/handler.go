// Package handlers implements the MediaService RPCs.
//
// Brokers presigned uploads / downloads against Cloudflare R2. Bytes flow
// client → R2; this service never touches plaintext or ciphertext.
package handlers

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixnats"
	"github.com/velix/backend/pkg/velixobs"
	"github.com/velix/backend/pkg/velixsql"
)

const (
	MaxMediaSizeBytes  = 100 * 1024 * 1024 // 100 MB
	UploadURLLifetime  = 15 * time.Minute
	DownloadURLLifetime = 5 * time.Minute
)

// Allowed content_type_class values.
var allowedContentClasses = map[string]struct{}{
	"image": {}, "video": {}, "audio": {}, "voice": {}, "file": {}, "sticker": {},
}

type Deps struct {
	TxRunner velixsql.TxRunner
	Media    MediaStore
	Storage  PresignedStorage
	Events   velixnats.Publisher
	Clock    Clock
	IDs      IDGenerator
	Log      velixobs.Logger
	Metrics  *Metrics
}

type MediaHandlers struct {
	tx      velixsql.TxRunner
	media   MediaStore
	storage PresignedStorage
	events  velixnats.Publisher
	clock   Clock
	ids     IDGenerator
	log     velixobs.Logger
	metrics *Metrics
}

func NewHandlers(d Deps) *MediaHandlers {
	return &MediaHandlers{
		tx: d.TxRunner, media: d.Media, storage: d.Storage,
		events: d.Events, clock: d.Clock, ids: d.IDs, log: d.Log, metrics: d.Metrics,
	}
}

type MediaRow struct {
	ID                string
	OwnerAccountID    string
	ContentTypeClass  string
	SizeBytes         int64
	State             string // "pending" | "uploaded" | "deleted"
	CiphertextBlake3  []byte
	CreatedAt         time.Time
	FinalizedAt       *time.Time
}

type MediaStore interface {
	InsertPending(ctx context.Context, tx velixsql.Tx, m MediaRow) error
	GetByID(ctx context.Context, tx velixsql.Tx, id string) (MediaRow, error)
	MarkUploaded(ctx context.Context, tx velixsql.Tx, id string, ciphertextBlake3 []byte, finalizedAt time.Time) error
	MarkDeleted(ctx context.Context, tx velixsql.Tx, id string, at time.Time) error
}

// PresignedStorage is the R2 abstraction. Production wires aws-sdk-go-v2 + R2.
type PresignedStorage interface {
	PresignPut(ctx context.Context, key string, sizeBytes int64, ttl time.Duration) (url string, headers map[string]string, err error)
	PresignGet(ctx context.Context, key string, ttl time.Duration) (url string, err error)
	HeadObject(ctx context.Context, key string) (sizeBytes int64, exists bool, err error)
	DeleteObject(ctx context.Context, key string) error
}

type Clock interface {
	Now() time.Time
}

type IDGenerator interface {
	NewULID() (string, error)
}

type Metrics struct {
	UploadsCreated   velixobs.Counter
	UploadsFinalized velixobs.Counter
	DownloadsIssued  velixobs.Counter
	Deleted          velixobs.Counter
}

// ----- CreateUpload --------------------------------------------------------

type CreateUploadRequest struct {
	IdempotencyKey   string
	ContentTypeClass string
	SizeBytes        int64
}

type CreateUploadResponse struct {
	MediaID            string
	UploadURL          string
	UploadHeaders      map[string]string
	UploadURLExpiresAt time.Time
}

func (h *MediaHandlers) CreateUpload(ctx context.Context, req *CreateUploadRequest) (*CreateUploadResponse, error) {
	if req == nil || req.IdempotencyKey == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "idempotency_key required")
	}
	if _, ok := allowedContentClasses[req.ContentTypeClass]; !ok {
		return nil, velixerr.New(velixerr.CodeInvalid, "content_type_class invalid")
	}
	if req.SizeBytes <= 0 || req.SizeBytes > MaxMediaSizeBytes {
		return nil, velixerr.New(velixerr.CodeInvalid, "size_bytes out of range")
	}
	owner := velixctx.AccountID(ctx)
	if owner == "" {
		return nil, velixerr.New(velixerr.CodeUnauthorized, "principal required")
	}

	mediaID, err := h.ids.NewULID()
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "id gen", err)
	}
	now := h.clock.Now().UTC()
	expires := now.Add(UploadURLLifetime)

	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return h.media.InsertPending(ctx, tx, MediaRow{
			ID: mediaID, OwnerAccountID: owner,
			ContentTypeClass: req.ContentTypeClass, SizeBytes: req.SizeBytes,
			State: "pending", CreatedAt: now,
		})
	}); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "insert pending", err)
	}

	url, headers, err := h.storage.PresignPut(ctx, objectKey(owner, mediaID), req.SizeBytes, UploadURLLifetime)
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeUnavailable, "presign put", err)
	}
	h.metrics.UploadsCreated.Inc()
	return &CreateUploadResponse{
		MediaID: mediaID, UploadURL: url, UploadHeaders: headers, UploadURLExpiresAt: expires,
	}, nil
}

// ----- FinalizeUpload ------------------------------------------------------

type FinalizeUploadRequest struct {
	IdempotencyKey   string
	MediaID          string
	CiphertextBlake3 []byte
}

type FinalizeUploadResponse struct {
	FinalizedAt time.Time
}

func (h *MediaHandlers) FinalizeUpload(ctx context.Context, req *FinalizeUploadRequest) (*FinalizeUploadResponse, error) {
	if req == nil || req.MediaID == "" || req.IdempotencyKey == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "media_id and idempotency_key required")
	}
	if len(req.CiphertextBlake3) != 32 {
		return nil, velixerr.New(velixerr.CodeInvalid, "ciphertext_blake3 must be 32 bytes")
	}
	owner := velixctx.AccountID(ctx)

	now := h.clock.Now().UTC()
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := h.media.GetByID(ctx, tx, req.MediaID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "media not found", err)
		}
		if row.OwnerAccountID != owner {
			return velixerr.New(velixerr.CodeForbidden, "not owner")
		}
		if row.State != "pending" {
			return velixerr.New(velixerr.CodeConflict, "already finalized")
		}
		size, exists, err := h.storage.HeadObject(ctx, objectKey(owner, row.ID))
		if err != nil {
			return velixerr.Wrap(velixerr.CodeUnavailable, "head", err)
		}
		if !exists {
			return velixerr.New(velixerr.CodeInvalid, "object missing in storage")
		}
		if size != row.SizeBytes {
			return velixerr.New(velixerr.CodeInvalid, "size mismatch")
		}
		return h.media.MarkUploaded(ctx, tx, row.ID, req.CiphertextBlake3, now)
	}); err != nil {
		return nil, err
	}
	h.metrics.UploadsFinalized.Inc()
	return &FinalizeUploadResponse{FinalizedAt: now}, nil
}

// ----- IssueDownload -------------------------------------------------------

type IssueDownloadRequest struct {
	MediaID string
}

type IssueDownloadResponse struct {
	DownloadURL          string
	DownloadURLExpiresAt time.Time
}

func (h *MediaHandlers) IssueDownload(ctx context.Context, req *IssueDownloadRequest) (*IssueDownloadResponse, error) {
	if req == nil || req.MediaID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "media_id required")
	}
	now := h.clock.Now().UTC()
	expires := now.Add(DownloadURLLifetime)

	var ownerKey string
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := h.media.GetByID(ctx, tx, req.MediaID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "media not found", err)
		}
		if row.State != "uploaded" {
			return velixerr.New(velixerr.CodeNotFound, "media not finalized")
		}
		ownerKey = objectKey(row.OwnerAccountID, row.ID)
		return nil
	}); err != nil {
		return nil, err
	}
	url, err := h.storage.PresignGet(ctx, ownerKey, DownloadURLLifetime)
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeUnavailable, "presign get", err)
	}
	h.metrics.DownloadsIssued.Inc()
	return &IssueDownloadResponse{DownloadURL: url, DownloadURLExpiresAt: expires}, nil
}

// ----- DeleteMedia ---------------------------------------------------------

type DeleteMediaRequest struct {
	IdempotencyKey string
	MediaID        string
}

type DeleteMediaResponse struct{}

func (h *MediaHandlers) DeleteMedia(ctx context.Context, req *DeleteMediaRequest) (*DeleteMediaResponse, error) {
	if req == nil || req.MediaID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "media_id required")
	}
	owner := velixctx.AccountID(ctx)
	now := h.clock.Now().UTC()
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := h.media.GetByID(ctx, tx, req.MediaID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "media not found", err)
		}
		if row.OwnerAccountID != owner {
			return velixerr.New(velixerr.CodeForbidden, "not owner")
		}
		if row.State == "deleted" {
			return nil // idempotent
		}
		if err := h.media.MarkDeleted(ctx, tx, row.ID, now); err != nil {
			return velixerr.Wrap(velixerr.CodeInternal, "mark deleted", err)
		}
		// R2 deletion runs through the lifecycle reconciler; we do not block here.
		return nil
	}); err != nil {
		return nil, err
	}
	h.metrics.Deleted.Inc()
	return &DeleteMediaResponse{}, nil
}

// objectKey is the canonical R2 layout: <owner>/<media_id>. Owner is the
// per-tenant prefix; per-object key is the ULID.
func objectKey(ownerAccountID, mediaID string) string {
	return ownerAccountID + "/" + mediaID
}
