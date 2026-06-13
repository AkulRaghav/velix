// Package grpcserver adapts the generated CallServiceServer to the call
// business-logic handlers.
package grpcserver

import (
	"context"

	"google.golang.org/protobuf/types/known/timestamppb"

	callv1 "github.com/velix/backend/proto/gen/go/velix/call/v1"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/call/internal/handlers"
)

type Server struct {
	callv1.UnimplementedCallServiceServer
	h *handlers.CallHandlers
}

func New(h *handlers.CallHandlers) *Server { return &Server{h: h} }

func (s *Server) CreateCall(ctx context.Context, req *callv1.CreateCallRequest) (*callv1.CreateCallResponse, error) {
	out, err := s.h.CreateCall(ctx, &handlers.CreateCallRequest{
		IdempotencyKey: req.GetIdempotencyKey(),
		ConversationID: req.GetConversationId(),
		Mode:           req.GetMode(),
		SecurityMode:   req.GetSecurityMode(),
	})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &callv1.CreateCallResponse{
		CallId:         out.CallID,
		LivekitRoom:    out.LiveKitRoom,
		LivekitToken:   out.LiveKitToken,
		TokenExpiresAt: timestamppb.New(out.TokenExpiresAt),
	}, nil
}

func (s *Server) IssueCallToken(ctx context.Context, req *callv1.IssueCallTokenRequest) (*callv1.IssueCallTokenResponse, error) {
	out, err := s.h.IssueCallToken(ctx, &handlers.IssueCallTokenRequest{CallID: req.GetCallId()})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &callv1.IssueCallTokenResponse{
		LivekitToken:   out.LiveKitToken,
		TokenExpiresAt: timestamppb.New(out.TokenExpiresAt),
	}, nil
}

func (s *Server) EndCall(ctx context.Context, req *callv1.EndCallRequest) (*callv1.EndCallResponse, error) {
	if _, err := s.h.EndCall(ctx, &handlers.EndCallRequest{
		IdempotencyKey: req.GetIdempotencyKey(),
		CallID:         req.GetCallId(),
	}); err != nil {
		return nil, velixerr.Status(err)
	}
	return &callv1.EndCallResponse{}, nil
}

func (s *Server) RejectCall(ctx context.Context, req *callv1.RejectCallRequest) (*callv1.RejectCallResponse, error) {
	if _, err := s.h.RejectCall(ctx, &handlers.RejectCallRequest{
		IdempotencyKey: req.GetIdempotencyKey(),
		CallID:         req.GetCallId(),
		Reason:         req.GetReason(),
	}); err != nil {
		return nil, velixerr.Status(err)
	}
	return &callv1.RejectCallResponse{}, nil
}
