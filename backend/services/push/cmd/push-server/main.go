// Command push-server runs the PushService.
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

	pushv1 "github.com/velix/backend/proto/gen/go/velix/push/v1"
	"github.com/velix/backend/pkg/velixgrpcauth"
	"github.com/velix/backend/pkg/velixhealth"
	"github.com/velix/backend/pkg/velixnatsjs"
	"github.com/velix/backend/pkg/velixtoken"
	"github.com/velix/backend/pkg/velixobsslog"
	"github.com/velix/backend/pkg/velixsqlpgx"
	"github.com/velix/backend/services/push/internal/adapters"
	"github.com/velix/backend/services/push/internal/grpcserver"
	"github.com/velix/backend/services/push/internal/handlers"
	"github.com/velix/backend/services/push/internal/pgxstore"
)

type Config struct {
	Addr     string
	HealthAddr string
	DSN      string
	NATSURL  string
	TokenKey string
	LogLevel string
}

func loadConfig() Config {
	return Config{
		Addr:     env("VELIX_ADDR", ":8080"),
		HealthAddr: env("VELIX_HEALTH_ADDR", ":8081"),
		DSN:      env("VELIX_DSN", ""),
		NATSURL:  env("VELIX_NATS_URL", ""),
		TokenKey: env("VELIX_TOKEN_KEY", ""),
		LogLevel: env("VELIX_LOG_LEVEL", "info"),
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
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if err := run(ctx, loadConfig()); err != nil {
		fmt.Fprintln(os.Stderr, "push-server fatal:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, cfg Config) error {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	log := velixobsslog.NewLogger(logger)
	meter := velixobsslog.NewMeter()

	if cfg.DSN == "" {
		return errors.New("VELIX_DSN is required")
	}
	if cfg.NATSURL == "" {
		return errors.New("VELIX_NATS_URL is required")
	}
	if cfg.TokenKey == "" {
		return errors.New("VELIX_TOKEN_KEY is required")
	}

	pool, err := velixsqlpgx.Connect(ctx, cfg.DSN)
	if err != nil {
		return fmt.Errorf("pgx connect: %w", err)
	}
	defer pool.Close()

	pub, nc, err := velixnatsjs.Connect(ctx, cfg.NATSURL, "VELIX_PUSH", []string{"velix.push.>"})
	if err != nil {
		return err
	}
	defer nc.Close()

	h := handlers.NewHandlers(handlers.Deps{
		TxRunner: pool,
		Tokens:   pgxstore.NewTokenStore(),
		Events:   pub,
		Clock:    adapters.SystemClock{},
		IDs:      adapters.NewULIDGenerator(),
		Log:      log,
		Metrics: &handlers.Metrics{
			TokensRegistered: meter.Counter("push_tokens_registered"),
			TokensRevoked:    meter.Counter("push_tokens_revoked"),
		},
	})

	srv := grpc.NewServer(
		grpc.UnaryInterceptor(velixgrpcauth.UnaryInterceptor(
			velixtoken.NewVerifier([]byte(cfg.TokenKey)),
			velixgrpcauth.StaticPostures(nil),
		)),
	)
	pushv1.RegisterPushServiceServer(srv, grpcserver.New(h))

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
		log.Info(ctx, "push-server listening", "addr", cfg.Addr, "health", cfg.HealthAddr, "revision", gitRevision)
		serveErr <- srv.Serve(lis)
	}()
	select {
	case <-ctx.Done():
		srv.GracefulStop()
		return nil
	case err := <-serveErr:
		return err
	case err := <-healthErr:
		return err
	}
}
