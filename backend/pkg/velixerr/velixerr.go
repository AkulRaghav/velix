// Package velixerr is the canonical error model for Velix Go services.
//
// We do not use raw `errors.New`. Every error is constructed through this
// package so:
//   - the gRPC status code is set deliberately
//   - a stable error code is attached for observability
//   - PII never enters the message
//   - wrapping preserves the chain for `errors.Is/As`
package velixerr

import (
	"errors"
	"fmt"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Code is a stable, narrow taxonomy. Map to gRPC codes via grpcCode().
type Code string

const (
	CodeInvalid       Code = "invalid_argument"
	CodeUnauthorized  Code = "unauthenticated"
	CodeForbidden     Code = "permission_denied"
	CodeNotFound      Code = "not_found"
	CodeConflict      Code = "conflict"
	CodeRateLimited   Code = "rate_limited"
	CodeUnavailable   Code = "unavailable"
	CodeDeadline      Code = "deadline_exceeded"
	CodeInternal      Code = "internal"
)

// Error is the structured error type. Implements error; carries a stable
// code; wraps any underlying cause.
type Error struct {
	C       Code
	Message string
	Cause   error
}

func (e *Error) Error() string {
	if e.Cause == nil {
		return fmt.Sprintf("%s: %s", e.C, e.Message)
	}
	return fmt.Sprintf("%s: %s: %v", e.C, e.Message, e.Cause)
}

func (e *Error) Unwrap() error { return e.Cause }

// New constructs a fresh Error.
func New(code Code, message string) *Error {
	return &Error{C: code, Message: message}
}

// Wrap wraps an existing error with the given code and message.
func Wrap(code Code, message string, cause error) *Error {
	return &Error{C: code, Message: message, Cause: cause}
}

// CodeOf extracts the structured code from an error chain. Returns
// CodeInternal if no Velix error is present.
func CodeOf(err error) Code {
	if err == nil {
		return ""
	}
	var ve *Error
	if errors.As(err, &ve) {
		return ve.C
	}
	return CodeInternal
}

// Status maps a Velix error to a gRPC status. Use this at the very edge of
// each handler to emit clean responses.
func Status(err error) error {
	if err == nil {
		return nil
	}
	var ve *Error
	if !errors.As(err, &ve) {
		return status.Error(codes.Internal, "internal error")
	}
	return status.Error(grpcCode(ve.C), ve.Message)
}

func grpcCode(c Code) codes.Code {
	switch c {
	case CodeInvalid:
		return codes.InvalidArgument
	case CodeUnauthorized:
		return codes.Unauthenticated
	case CodeForbidden:
		return codes.PermissionDenied
	case CodeNotFound:
		return codes.NotFound
	case CodeConflict:
		return codes.AlreadyExists
	case CodeRateLimited:
		return codes.ResourceExhausted
	case CodeUnavailable:
		return codes.Unavailable
	case CodeDeadline:
		return codes.DeadlineExceeded
	default:
		return codes.Internal
	}
}
