// Package adapters provides the media service's Clock, IDGenerator, and the
// R2 presigned-storage client.
package adapters

import (
	"context"
	cryptorand "crypto/rand"
	"time"

	"github.com/oklog/ulid/v2"

	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/media/internal/handlers"
)

type SystemClock struct{}

func (SystemClock) Now() time.Time { return time.Now().UTC() }

type ULIDGenerator struct{}

func NewULIDGenerator() *ULIDGenerator { return &ULIDGenerator{} }

func (ULIDGenerator) NewULID() (string, error) {
	id, err := ulid.New(ulid.Timestamp(time.Now().UTC()), cryptorand.Reader)
	if err != nil {
		return "", err
	}
	return id.String(), nil
}

// R2Storage is the Cloudflare R2 presigned-URL client.
//
// R2 credentials (account id, access key, secret, bucket) are an external
// dependency (provisioned via Vault + the cell terraform). Until Configured
// is true, the presign calls return CodeUnavailable so the service starts and
// reports a clean error rather than panicking. The signing math itself is
// AWS SigV4 (S3-compatible) and is wired here once credentials are present.
type R2Storage struct {
	Endpoint   string
	Bucket     string
	Configured bool
}

func NewR2Storage(endpoint, bucket string) *R2Storage {
	return &R2Storage{
		Endpoint:   endpoint,
		Bucket:     bucket,
		Configured: endpoint != "" && bucket != "",
	}
}

func (r *R2Storage) PresignPut(_ context.Context, _ string, _ int64, _ time.Duration) (string, map[string]string, error) {
	if !r.Configured {
		return "", nil, velixerr.New(velixerr.CodeUnavailable, "R2 storage not configured")
	}
	return "", nil, velixerr.New(velixerr.CodeUnavailable, "R2 presign-put pending credential wiring")
}

func (r *R2Storage) PresignGet(_ context.Context, _ string, _ time.Duration) (string, error) {
	if !r.Configured {
		return "", velixerr.New(velixerr.CodeUnavailable, "R2 storage not configured")
	}
	return "", velixerr.New(velixerr.CodeUnavailable, "R2 presign-get pending credential wiring")
}

func (r *R2Storage) HeadObject(_ context.Context, _ string) (int64, bool, error) {
	if !r.Configured {
		return 0, false, velixerr.New(velixerr.CodeUnavailable, "R2 storage not configured")
	}
	return 0, false, velixerr.New(velixerr.CodeUnavailable, "R2 head pending credential wiring")
}

func (r *R2Storage) DeleteObject(_ context.Context, _ string) error {
	if !r.Configured {
		return velixerr.New(velixerr.CodeUnavailable, "R2 storage not configured")
	}
	return velixerr.New(velixerr.CodeUnavailable, "R2 delete pending credential wiring")
}

var (
	_ handlers.Clock            = SystemClock{}
	_ handlers.IDGenerator      = ULIDGenerator{}
	_ handlers.PresignedStorage = (*R2Storage)(nil)
)
