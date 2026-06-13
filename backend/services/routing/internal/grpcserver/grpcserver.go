// Package grpcserver adapts the generated RoutingServiceServer interface to
// the storage-agnostic *handlers.RoutingHandlers. It translates between the
// proto-generated message types and the handler's internal request/response
// shapes, keeping the handler package free of any proto dependency.
package grpcserver

import (
	"context"

	"google.golang.org/protobuf/types/known/timestamppb"

	routingv1 "github.com/velix/backend/proto/gen/go/velix/routing/v1"
	"github.com/velix/backend/services/routing/internal/handlers"
)

// Server implements routingv1.RoutingServiceServer by delegating to the
// business-logic handlers.
type Server struct {
	routingv1.UnimplementedRoutingServiceServer
	h *handlers.RoutingHandlers
}

func New(h *handlers.RoutingHandlers) *Server { return &Server{h: h} }

// SendEnvelope translates the proto request, invokes the handler, and maps
// the response back to proto.
func (s *Server) SendEnvelope(
	ctx context.Context,
	req *routingv1.SendEnvelopeRequest,
) (*routingv1.SendEnvelopeResponse, error) {
	in := &handlers.SendEnvelopeRequest{
		IdempotencyKey: req.GetIdempotencyKey(),
		Recipients:     make([]handlers.EnvelopeRecipient, 0, len(req.GetRecipients())),
	}
	for _, r := range req.GetRecipients() {
		in.Recipients = append(in.Recipients, handlers.EnvelopeRecipient{
			RecipientAccountID: r.GetRecipientAccountId(),
			RecipientDeviceID:  r.GetRecipientDeviceId(),
			Ciphertext:         r.GetCiphertext(),
		})
	}

	out, err := s.h.SendEnvelope(ctx, in)
	if err != nil {
		return nil, err
	}

	resp := &routingv1.SendEnvelopeResponse{
		Delivered: make([]*routingv1.DeliveredEnvelope, 0, len(out.Delivered)),
	}
	for _, d := range out.Delivered {
		resp.Delivered = append(resp.Delivered, &routingv1.DeliveredEnvelope{
			RecipientDeviceId: d.RecipientDeviceID,
			EnvelopeId:        d.EnvelopeID,
			EnqueuedAt:        timestamppb.New(d.EnqueuedAt),
		})
	}
	return resp, nil
}
