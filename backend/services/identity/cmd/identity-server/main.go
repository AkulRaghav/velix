// Command identity-server runs the IdentityService.
//
// Wires the pgx pool (via velixsqlpgx) to the handler stores, a SHA-256
// identity hasher, an Ed25519 attestation verifier, an HMAC token issuer,
// and a slog-backed logger/meter, then serves gRPC on VELIX_ADDR.
//
// Configuration is entirely from env (12-factor); see docs/phase-10/05-config.md.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	"google.golang.org/grpc"

	identityv1 "github.com/velix/backend/proto/gen/go/velix/identity/v1"
	"github.com/velix/backend/pkg/velixauth"
	"github.com/velix/backend/pkg/velixgrpcauth"
	"github.com/velix/backend/pkg/velixhealth"
	"github.com/velix/backend/pkg/velixobsslog"
	"github.com/velix/backend/pkg/velixsqlpgx"
	"github.com/velix/backend/services/identity/internal/adapters"
	"github.com/velix/backend/services/identity/internal/grpcserver"
	"github.com/velix/backend/services/identity/internal/handlers"
	"github.com/velix/backend/services/identity/internal/pgxstore"
	"github.com/velix/backend/services/identity/internal/tokens"
)

type Config struct {
	Addr       string
	HealthAddr string
	Cell       string
	DSN        string
	NATSURL    string
	VaultAddr  string
	TokenKey   string
	LogLevel   string
}

func loadConfig() Config {
	return Config{
		Addr:       env("VELIX_ADDR", ":8080"),
		HealthAddr: env("VELIX_HEALTH_ADDR", ":8081"),
		Cell:       env("VELIX_CELL", "us-east-1"),
		DSN:        env("VELIX_DSN", ""),
		NATSURL:    env("VELIX_NATS_URL", ""),
		VaultAddr:  env("VELIX_VAULT_ADDR", ""),
		TokenKey:   env("VELIX_TOKEN_KEY", ""),
		LogLevel:   env("VELIX_LOG_LEVEL", "info"),
	}
}

func env(k, def string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return def
}

// gitRevision is injected at build time via -ldflags "-X main.gitRevision=...".
var gitRevision = "dev"

func main() {
	cfg := loadConfig()

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	if err := run(ctx, cfg); err != nil {
		fmt.Fprintln(os.Stderr, "identity-server fatal:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, cfg Config) error {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: parseLevel(cfg.LogLevel)}))
	log := velixobsslog.NewLogger(logger)
	meter := velixobsslog.NewMeter()

	if cfg.DSN == "" {
		return errors.New("VELIX_DSN is required")
	}
	if cfg.TokenKey == "" {
		return errors.New("VELIX_TOKEN_KEY is required")
	}

	pool, err := velixsqlpgx.Connect(ctx, cfg.DSN)
	if err != nil {
		return fmt.Errorf("pgx connect: %w", err)
	}
	defer pool.Close()

	tokenIssuer := tokens.New([]byte(cfg.TokenKey))

	h := handlers.NewHandlers(handlers.Deps{
		TxRunner: pool,
		Accounts: pgxstore.NewAccountStore(),
		Devices:  pgxstore.NewDeviceStore(),
		Prekeys:  pgxstore.NewPrekeyStore(),
		Sessions: pgxstore.NewSessionStore(),
		Tokens:   tokenIssuer,
		Clock:    adapters.SystemClock{},
		IDs:      adapters.NewULIDGenerator(),
		Hasher:   adapters.SHA256Hasher{},
		Sigs:     adapters.Ed25519Verifier{},
		Log:      log,
		Metrics: &handlers.Metrics{
			AccountsCreated:     meter.Counter("identity_accounts_created"),
			DevicesPaired:       meter.Counter("identity_devices_paired"),
			PrekeysPublished:    meter.Counter("identity_prekeys_published"),
			PrekeyConsumed:      meter.Counter("identity_prekey_consumed"),
			SignInLatencyMillis: meter.Histogram("identity_signin_latency_ms"),
		},
	})

	srv := grpc.NewServer(
		grpc.UnaryInterceptor(velixgrpcauth.UnaryInterceptor(
			adapters.NewBearerVerifier(tokenIssuer),
			velixgrpcauth.StaticPostures(map[string]velixauth.Posture{
				identityv1.IdentityService_CreateAccount_FullMethodName:     velixauth.PostureNone,
				identityv1.IdentityService_SignIn_FullMethodName:            velixauth.PostureNone,
				identityv1.IdentityService_RefreshToken_FullMethodName:      velixauth.PostureNone,
				identityv1.IdentityService_FetchPrekeyBundle_FullMethodName: velixauth.PostureNone,
				// All other methods default to PostureClient (bearer required).
			}),
		)),
	)
	identityv1.RegisterIdentityServiceServer(srv, grpcserver.New(h))

	lis, err := net.Listen("tcp", cfg.Addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", cfg.Addr, err)
	}

	health := velixhealth.New([]velixhealth.ReadinessCheck{
		{Name: "postgres", Check: pool.Ping},
	}, nil)
	health.SetReady(true)
	healthErr := make(chan error, 1)
	go func() { healthErr <- health.ListenAndServe(ctx, cfg.HealthAddr) }()

	serveErr := make(chan error, 1)
	go func() {
		log.Info(ctx, "identity-server listening", "addr", cfg.Addr, "cell", cfg.Cell, "health", cfg.HealthAddr, "revision", gitRevision)
		serveErr <- srv.Serve(lis)
	}()

	select {
	case <-ctx.Done():
		log.Info(ctx, "shutdown signal received")
		srv.GracefulStop()
		return nil
	case err := <-serveErr:
		return err
	case err := <-healthErr:
		return err
	}
}

func parseLevel(s string) slog.Level {
	switch s {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
