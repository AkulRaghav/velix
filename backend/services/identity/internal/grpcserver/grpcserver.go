// Package grpcserver adapts the generated IdentityServiceServer interface to
// the *handlers.IdentityHandlers. The three RPCs whose business logic exists
// in the handlers package (CreateAccount, PublishPrekeys, FetchPrekeyBundle)
// are translated here; the remaining RPCs fall through to the generated
// Unimplemented base until their handler logic lands.
package grpcserver

import (
	"context"

	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/velix/backend/proto/gen/go/velix/identity/v1"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/identity/internal/handlers"
)

// Server implements identityv1.IdentityServiceServer.
type Server struct {
	identityv1.UnimplementedIdentityServiceServer
	h *handlers.IdentityHandlers
}

func New(h *handlers.IdentityHandlers) *Server { return &Server{h: h} }

// CreateAccount translates proto ↔ handler types and maps domain errors to
// gRPC status codes via velixerr.Status.
func (s *Server) CreateAccount(
	ctx context.Context, req *identityv1.CreateAccountRequest,
) (*identityv1.CreateAccountResponse, error) {
	in := &handlers.CreateAccountRequest{
		IdempotencyKey:       req.GetIdempotencyKey(),
		IdentityPublicKey:    req.GetIdentityPublicKey(),
		DevicePublicKey:      req.GetDevicePublicKey(),
		AttestationSignature: req.GetAttestationSignature(),
		SignedAt:             req.GetSignedAt().AsTime(),
		Handle:               req.GetHandle(),
		DeviceName:           req.GetDeviceName(),
		DevicePlatform:       req.GetDevicePlatform(),
		Locale:               req.GetLocale(),
	}
	out, err := s.h.CreateAccount(ctx, in)
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &identityv1.CreateAccountResponse{
		Account: &identityv1.Account{
			Id:        out.Account.ID,
			Handle:    in.Handle,
			Locale:    out.Account.Locale,
			CreatedAt: timestamppb.New(out.Account.CreatedAt),
		},
		Device: &identityv1.Device{
			Id:         out.Device.ID,
			AccountId:  out.Device.AccountID,
			Name:       out.Device.Name,
			Platform:   out.Device.Platform,
			PairedAt:   timestamppb.New(out.Device.PairedAt),
			LastSeenAt: timestamppb.New(out.Device.LastSeenAt),
			Status:     out.Device.Status,
		},
		Tokens: &identityv1.TokenPair{
			AccessToken:      out.Tokens.AccessToken,
			RefreshToken:     out.Tokens.RefreshToken,
			AccessExpiresAt:  timestamppb.New(out.Tokens.AccessExpiresAt),
			RefreshExpiresAt: timestamppb.New(out.Tokens.RefreshExpiresAt),
		},
	}, nil
}

// PublishPrekeys uploads a signed prekey + one-time prekeys.
func (s *Server) PublishPrekeys(
	ctx context.Context, req *identityv1.PublishPrekeysRequest,
) (*identityv1.PublishPrekeysResponse, error) {
	in := &handlers.PublishPrekeysRequest{
		SignedPrekey:          req.GetSignedPrekey(),
		SignedPrekeySignature: req.GetSignedPrekeySignature(),
		SignedAt:              req.GetSignedAt().AsTime(),
		OneTimePrekeys:        req.GetOneTimePrekeys(),
	}
	if _, err := s.h.PublishPrekeys(ctx, in); err != nil {
		return nil, velixerr.Status(err)
	}
	return &identityv1.PublishPrekeysResponse{}, nil
}

// FetchPrekeyBundle returns the X3DH bundle, consuming one one-time prekey.
func (s *Server) FetchPrekeyBundle(
	ctx context.Context, req *identityv1.FetchPrekeyBundleRequest,
) (*identityv1.FetchPrekeyBundleResponse, error) {
	in := &handlers.FetchPrekeyBundleRequest{
		AccountID: req.GetAccountId(),
		DeviceID:  req.GetDeviceId(),
	}
	bundle, err := s.h.FetchPrekeyBundle(ctx, in)
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &identityv1.FetchPrekeyBundleResponse{
		IdentityPublicKey:     bundle.IdentityPublicKey,
		SignedPrekey:          bundle.SignedPrekey,
		SignedPrekeySignature: bundle.SignedPrekeySignature,
		OneTimePrekey:         bundle.OneTimePrekey,
	}, nil
}
