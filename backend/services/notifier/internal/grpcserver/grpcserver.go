// Package grpcserver adapts the generated NotifierServiceServer to the
// notifier business-logic handlers.
package grpcserver

import (
	"context"

	"google.golang.org/protobuf/types/known/timestamppb"

	notifierv1 "github.com/velix/backend/proto/gen/go/velix/notifier/v1"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/notifier/internal/handlers"
)

type Server struct {
	notifierv1.UnimplementedNotifierServiceServer
	h *handlers.NotifierHandlers
}

func New(h *handlers.NotifierHandlers) *Server { return &Server{h: h} }

func (s *Server) EnqueuePush(ctx context.Context, req *notifierv1.EnqueuePushRequest) (*notifierv1.EnqueuePushResponse, error) {
	out, err := s.h.EnqueuePush(ctx, &handlers.EnqueuePushRequest{
		EventID:          req.GetEventId(),
		DeviceID:         req.GetDeviceId(),
		EncryptedPayload: req.GetEncryptedPayload(),
		ExpiresAt:        req.GetExpiresAt().AsTime(),
		Priority:         req.GetPriority(),
	})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &notifierv1.EnqueuePushResponse{DeliveryId: out.DeliveryID}, nil
}

func (s *Server) GetPushStatus(ctx context.Context, req *notifierv1.GetPushStatusRequest) (*notifierv1.GetPushStatusResponse, error) {
	out, err := s.h.GetPushStatus(ctx, &handlers.GetPushStatusRequest{DeliveryID: req.GetDeliveryId()})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &notifierv1.GetPushStatusResponse{
		State:         out.State,
		Platform:      out.Platform,
		UpdatedAt:     timestamppb.New(out.UpdatedAt),
		FailureReason: out.FailureReason,
	}, nil
}
