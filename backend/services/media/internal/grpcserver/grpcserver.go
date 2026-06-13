// Package grpcserver adapts the generated MediaServiceServer to the media
// business-logic handlers.
package grpcserver

import (
	"context"

	"google.golang.org/protobuf/types/known/timestamppb"

	mediav1 "github.com/velix/backend/proto/gen/go/velix/media/v1"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/media/internal/handlers"
)

type Server struct {
	mediav1.UnimplementedMediaServiceServer
	h *handlers.MediaHandlers
}

func New(h *handlers.MediaHandlers) *Server { return &Server{h: h} }

func (s *Server) CreateUpload(ctx context.Context, req *mediav1.CreateUploadRequest) (*mediav1.CreateUploadResponse, error) {
	out, err := s.h.CreateUpload(ctx, &handlers.CreateUploadRequest{
		IdempotencyKey:   req.GetIdempotencyKey(),
		ContentTypeClass: req.GetContentTypeClass(),
		SizeBytes:        req.GetSizeBytes(),
	})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &mediav1.CreateUploadResponse{
		MediaId:            out.MediaID,
		UploadUrl:          out.UploadURL,
		UploadHeaders:      out.UploadHeaders,
		UploadUrlExpiresAt: timestamppb.New(out.UploadURLExpiresAt),
	}, nil
}

func (s *Server) FinalizeUpload(ctx context.Context, req *mediav1.FinalizeUploadRequest) (*mediav1.FinalizeUploadResponse, error) {
	out, err := s.h.FinalizeUpload(ctx, &handlers.FinalizeUploadRequest{
		IdempotencyKey:   req.GetIdempotencyKey(),
		MediaID:          req.GetMediaId(),
		CiphertextBlake3: req.GetCiphertextBlake3(),
	})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &mediav1.FinalizeUploadResponse{FinalizedAt: timestamppb.New(out.FinalizedAt)}, nil
}

func (s *Server) IssueDownload(ctx context.Context, req *mediav1.IssueDownloadRequest) (*mediav1.IssueDownloadResponse, error) {
	out, err := s.h.IssueDownload(ctx, &handlers.IssueDownloadRequest{MediaID: req.GetMediaId()})
	if err != nil {
		return nil, velixerr.Status(err)
	}
	return &mediav1.IssueDownloadResponse{
		DownloadUrl:          out.DownloadURL,
		DownloadUrlExpiresAt: timestamppb.New(out.DownloadURLExpiresAt),
	}, nil
}

func (s *Server) DeleteMedia(ctx context.Context, req *mediav1.DeleteMediaRequest) (*mediav1.DeleteMediaResponse, error) {
	if _, err := s.h.DeleteMedia(ctx, &handlers.DeleteMediaRequest{
		IdempotencyKey: req.GetIdempotencyKey(),
		MediaID:        req.GetMediaId(),
	}); err != nil {
		return nil, velixerr.Status(err)
	}
	return &mediav1.DeleteMediaResponse{}, nil
}
