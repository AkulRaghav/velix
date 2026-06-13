// Package adapters provides the call service Clock, IDGenerator, and the
// LiveKit client.
package adapters

import (
	"context"
	cryptorand "crypto/rand"
	"time"

	"github.com/oklog/ulid/v2"

	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/call/internal/handlers"
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

// LiveKit is the call service's LiveKit broker.
//
// The LiveKit cluster (API key/secret, host) is an external dependency
// (provisioned per cell). Until Configured is true, room/token operations
// return CodeUnavailable so the service starts cleanly and reports a precise
// error rather than panicking.
type LiveKit struct {
	Host       string
	APIKey     string
	APISecret  string
	Configured bool
}

func NewLiveKit(host, apiKey, apiSecret string) *LiveKit {
	return &LiveKit{
		Host:       host,
		APIKey:     apiKey,
		APISecret:  apiSecret,
		Configured: host != "" && apiKey != "" && apiSecret != "",
	}
}

func (l *LiveKit) CreateRoom(_ context.Context, _ string) error {
	if !l.Configured {
		return velixerr.New(velixerr.CodeUnavailable, "LiveKit not configured")
	}
	return velixerr.New(velixerr.CodeUnavailable, "LiveKit create-room pending credential wiring")
}

func (l *LiveKit) IssueToken(_ context.Context, _, _ string, _ bool, _ time.Duration) (string, error) {
	if !l.Configured {
		return "", velixerr.New(velixerr.CodeUnavailable, "LiveKit not configured")
	}
	return "", velixerr.New(velixerr.CodeUnavailable, "LiveKit issue-token pending credential wiring")
}

func (l *LiveKit) DeleteRoom(_ context.Context, _ string) error {
	if !l.Configured {
		return velixerr.New(velixerr.CodeUnavailable, "LiveKit not configured")
	}
	return velixerr.New(velixerr.CodeUnavailable, "LiveKit delete-room pending credential wiring")
}

var (
	_ handlers.Clock         = SystemClock{}
	_ handlers.IDGenerator   = ULIDGenerator{}
	_ handlers.LiveKitClient = (*LiveKit)(nil)
)
