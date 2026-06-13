// Package grpcserver adapts the generated PushServiceServer to the push
// business-logic handlers.
package grpcserver

import (
	"context"

	"google.golang.org/protobuf/types/known/timestamppb"

	pushv1 "github.com/velix/backend/proto/gen/go/velix/push/v1"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/push/internal/handlers"
)

type Server struct {
	pushv1.UnimplementedPushServiceServer
	h *handlers.PushHandlers
}

func New(h *handlers.PushHandlers) *Server { return &Server{h: h} }

func (s *Server) RegisterToken(ctx context.Context, req *pushv1.RegisterTokenRequest) (*pushv1.RegisterTokenResponse, error) {
	out, err := s.h.RegisterToken(ctx, &handlers.RegisterTokenRequest{
		IdempotencyKey:      req.GetIdempotencyKey(),
		DeviceID:            req.GetDeviceId(),
		Platform:            req.GetPlatform(),
		Token:               req.GetToken(),
		WebPushSubscription: req.GetWebpushSubscription(),
	})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &pushv1.RegisterTokenResponse{TokenId: out.TokenID}, nil
}

func (s *Server) RevokeToken(ctx context.Context, req *pushv1.RevokeTokenRequest) (*pushv1.RevokeTokenResponse, error) {
	if _, err := s.h.RevokeToken(ctx, &handlers.RevokeTokenRequest{TokenID: req.GetTokenId()}); err != nil {
		return nil, velixerr.Status(err)
	}
	return &pushv1.RevokeTokenResponse{}, nil
}

func (s *Server) ListTokens(ctx context.Context, _ *pushv1.ListTokensRequest) (*pushv1.ListTokensResponse, error) {
	out, err := s.h.ListTokens(ctx, &handlers.ListTokensRequest{})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	resp := &pushv1.ListTokensResponse{Tokens: make([]*pushv1.PushToken, 0, len(out.Tokens))}
	for _, t := range out.Tokens {
		resp.Tokens = append(resp.Tokens, &pushv1.PushToken{
			TokenId:      t.ID,
			DeviceId:     t.DeviceID,
			Platform:     t.Platform,
			RegisteredAt: timestamppb.New(t.RegisteredAt),
			LastUsedAt:   timestamppb.New(t.LastUsedAt),
			Status:       t.Status,
		})
	}
	return resp, nil
}
