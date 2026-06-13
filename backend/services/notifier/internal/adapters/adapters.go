// Package adapters provides the notifier service Clock, IDGenerator, and the
// push-provider clients (APNs / FCM / WebPush) plus the device→token lookup.
//
// APNs/FCM/WebPush credentials are external dependencies (Apple auth key,
// FCM service account, VAPID keys — provisioned via Vault). Until configured,
// Send returns CodeUnavailable so the service starts cleanly. TokenLookup
// queries the push service's token store; the gRPC client wiring lands with
// the cell service mesh.
package adapters

import (
	"context"
	cryptorand "crypto/rand"
	"time"

	"github.com/oklog/ulid/v2"

	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/notifier/internal/handlers"
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

// pushProvider is the shared "not configured" gate for the three providers.
type pushProvider struct {
	name       string
	configured bool
}

func (p pushProvider) send() error {
	if !p.configured {
		return velixerr.New(velixerr.CodeUnavailable, p.name+" not configured")
	}
	return velixerr.New(velixerr.CodeUnavailable, p.name+" send pending credential wiring")
}

// APNsClient.
type APNsClient struct{ pushProvider }

func NewAPNsClient(configured bool) *APNsClient {
	return &APNsClient{pushProvider{name: "APNs", configured: configured}}
}

func (c *APNsClient) Send(_ context.Context, _, _ []byte, _ time.Time, _ string) error {
	return c.send()
}

// FCMClient.
type FCMClient struct{ pushProvider }

func NewFCMClient(configured bool) *FCMClient {
	return &FCMClient{pushProvider{name: "FCM", configured: configured}}
}

func (c *FCMClient) Send(_ context.Context, _, _ []byte, _ time.Time, _ string) error {
	return c.send()
}

// WebPushClient.
type WebPushClient struct{ pushProvider }

func NewWebPushClient(configured bool) *WebPushClient {
	return &WebPushClient{pushProvider{name: "WebPush", configured: configured}}
}

func (c *WebPushClient) Send(_ context.Context, _, _ []byte, _ time.Time, _ string) error {
	return c.send()
}

// TokenLookup resolves a device to its push token. The production
// implementation calls the push service over gRPC; until that mesh wiring is
// live it returns NotFound so EnqueuePush fails cleanly rather than panicking.
type TokenLookup struct{ Configured bool }

func NewTokenLookup(configured bool) *TokenLookup { return &TokenLookup{Configured: configured} }

func (t *TokenLookup) ForDevice(_ context.Context, _ string) (string, []byte, []byte, error) {
	return "", nil, nil, velixerr.New(velixerr.CodeUnavailable, "token lookup pending push-service mesh wiring")
}

var (
	_ handlers.Clock         = SystemClock{}
	_ handlers.IDGenerator   = ULIDGenerator{}
	_ handlers.APNsClient    = (*APNsClient)(nil)
	_ handlers.FCMClient     = (*FCMClient)(nil)
	_ handlers.WebPushClient = (*WebPushClient)(nil)
	_ handlers.TokenLookup   = (*TokenLookup)(nil)
)
