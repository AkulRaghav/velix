package velixgrpcauth

import (
	"context"
	"errors"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/velix/backend/pkg/velixauth"
	"github.com/velix/backend/pkg/velixctx"
)

// fakeVerifier accepts the token "good" and rejects everything else.
type fakeVerifier struct{}

func (fakeVerifier) Verify(_ context.Context, bearer string) (velixauth.Principal, error) {
	if bearer == "good" {
		return velixauth.Principal{AccountID: "acc1", DeviceID: "dev1", ExpiresAt: time.Now().Add(time.Hour)}, nil
	}
	return velixauth.Principal{}, errors.New("bad token")
}

func ctxWithBearer(token string) context.Context {
	md := metadata.New(map[string]string{"authorization": "Bearer " + token})
	return metadata.NewIncomingContext(context.Background(), md)
}

func unaryInfo(method string) *grpc.UnaryServerInfo {
	return &grpc.UnaryServerInfo{FullMethod: method}
}

func TestUnary_ClientPosture_RequiresBearer(t *testing.T) {
	postures := StaticPostures(map[string]velixauth.Posture{
		"/svc/Protected": velixauth.PostureClient,
	})
	interceptor := UnaryInterceptor(fakeVerifier{}, postures)

	// No metadata → Unauthenticated.
	_, err := interceptor(context.Background(), nil, unaryInfo("/svc/Protected"),
		func(context.Context, any) (any, error) { return "ok", nil })
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("missing bearer: got %v, want Unauthenticated", status.Code(err))
	}
}

func TestUnary_ClientPosture_RejectsBadToken(t *testing.T) {
	postures := StaticPostures(map[string]velixauth.Posture{})
	interceptor := UnaryInterceptor(fakeVerifier{}, postures)
	_, err := interceptor(ctxWithBearer("bad"), nil, unaryInfo("/svc/Anything"),
		func(context.Context, any) (any, error) { return "ok", nil })
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("bad token: got %v, want Unauthenticated", status.Code(err))
	}
}

func TestUnary_ClientPosture_InjectsPrincipal(t *testing.T) {
	postures := StaticPostures(map[string]velixauth.Posture{})
	interceptor := UnaryInterceptor(fakeVerifier{}, postures)

	var gotAcc, gotDev string
	_, err := interceptor(ctxWithBearer("good"), nil, unaryInfo("/svc/Anything"),
		func(ctx context.Context, _ any) (any, error) {
			gotAcc = velixctx.AccountID(ctx)
			gotDev = velixctx.DeviceID(ctx)
			return "ok", nil
		})
	if err != nil {
		t.Fatalf("good token: %v", err)
	}
	if gotAcc != "acc1" || gotDev != "dev1" {
		t.Fatalf("principal not injected: acc=%q dev=%q", gotAcc, gotDev)
	}
}

func TestUnary_NonePosture_SkipsVerification(t *testing.T) {
	postures := StaticPostures(map[string]velixauth.Posture{
		"/svc/Public": velixauth.PostureNone,
	})
	interceptor := UnaryInterceptor(fakeVerifier{}, postures)

	called := false
	// No bearer at all, but PostureNone → handler runs.
	_, err := interceptor(context.Background(), nil, unaryInfo("/svc/Public"),
		func(context.Context, any) (any, error) { called = true; return "ok", nil })
	if err != nil {
		t.Fatalf("none posture should pass: %v", err)
	}
	if !called {
		t.Fatal("handler should have been called for PostureNone")
	}
}

func TestUnary_MalformedHeader(t *testing.T) {
	postures := StaticPostures(map[string]velixauth.Posture{})
	interceptor := UnaryInterceptor(fakeVerifier{}, postures)
	md := metadata.New(map[string]string{"authorization": "Token xyz"})
	ctx := metadata.NewIncomingContext(context.Background(), md)
	_, err := interceptor(ctx, nil, unaryInfo("/svc/Anything"),
		func(context.Context, any) (any, error) { return "ok", nil })
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("malformed header: got %v, want Unauthenticated", status.Code(err))
	}
}

// fakeStream is a minimal grpc.ServerStream carrying a context.
type fakeStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (f *fakeStream) Context() context.Context { return f.ctx }

func TestStream_InjectsPrincipal(t *testing.T) {
	postures := StaticPostures(map[string]velixauth.Posture{})
	interceptor := StreamInterceptor(fakeVerifier{}, postures)

	var gotAcc string
	err := interceptor(nil, &fakeStream{ctx: ctxWithBearer("good")},
		&grpc.StreamServerInfo{FullMethod: "/svc/Stream"},
		func(_ any, ss grpc.ServerStream) error {
			gotAcc = velixctx.AccountID(ss.Context())
			return nil
		})
	if err != nil {
		t.Fatalf("stream good token: %v", err)
	}
	if gotAcc != "acc1" {
		t.Fatalf("stream principal not injected: acc=%q", gotAcc)
	}
}
