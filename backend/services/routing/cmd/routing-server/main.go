// Command routing-server runs the RoutingService.
//
// Wires the handlers in internal/handlers to the production pgx, NATS
// JetStream, and Redis clients. See docs/phase-10/05-config.md for env
// configuration.
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
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc"

	routingv1 "github.com/velix/backend/proto/gen/go/velix/routing/v1"
	"github.com/velix/backend/pkg/velixhealth"
	"github.com/velix/backend/services/routing/internal/adapters"
	"github.com/velix/backend/services/routing/internal/authctx"
	"github.com/velix/backend/services/routing/internal/grpcserver"
	"github.com/velix/backend/services/routing/internal/handlers"
	"github.com/velix/backend/services/routing/internal/natspub"
	"github.com/velix/backend/services/routing/internal/pgxstore"
)

type Config struct {
	Addr       string
	HealthAddr string
	Cell       string
	DSN        string
	NATSURL    string
	RedisAddr  string
	VaultAddr  string
	LogLevel   string
}

func loadConfig() Config {
	return Config{
		Addr:       env("VELIX_ADDR", ":8080"),
		HealthAddr: env("VELIX_HEALTH_ADDR", ":8081"),
		Cell:       env("VELIX_CELL", "us-east-1"),
		DSN:        env("VELIX_DSN", ""),
		NATSURL:    env("VELIX_NATS_URL", ""),
		RedisAddr:  env("VELIX_REDIS_ADDR", ""),
		VaultAddr:  env("VELIX_VAULT_ADDR", ""),
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
		fmt.Fprintln(os.Stderr, "routing-server fatal:", err)
		os.Exit(1)
	}
}

// run wires production dependencies and serves until the context is cancelled.
//
// Required env for a full boot: VELIX_DSN (Postgres), VELIX_NATS_URL
// (JetStream), VELIX_REDIS_ADDR (typing/presence TTL). When VELIX_DSN is
// empty the process refuses to start rather than silently running without a
// durable store.
func run(ctx context.Context, cfg Config) error {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: parseLevel(cfg.LogLevel),
	}))

	if cfg.DSN == "" {
		return errors.New("VELIX_DSN is required")
	}
	if cfg.NATSURL == "" {
		return errors.New("VELIX_NATS_URL is required")
	}

	// Postgres.
	pool, err := pgxpool.New(ctx, cfg.DSN)
	if err != nil {
		return fmt.Errorf("pgx pool: %w", err)
	}
	defer pool.Close()
	if err := pool.Ping(ctx); err != nil {
		return fmt.Errorf("pgx ping: %w", err)
	}

	// NATS JetStream.
	pub, nc, err := natspub.Connect(ctx, cfg.NATSURL)
	if err != nil {
		return err
	}
	defer nc.Close()

	// Redis (typing/presence TTL). Optional: a missing addr disables it.
	var rdb *redis.Client
	if cfg.RedisAddr != "" {
		rdb = redis.NewClient(&redis.Options{Addr: cfg.RedisAddr})
		defer func() { _ = rdb.Close() }()
		if err := rdb.Ping(ctx).Err(); err != nil {
			return fmt.Errorf("redis ping: %w", err)
		}
	}

	txRunner, envelopes, idem := pgxstore.New(pool)

	h := handlers.NewHandlers(handlers.Deps{
		Auth:        authctx.New(),
		TxRunner:    txRunner,
		Envelopes:   envelopes,
		Idempotency: idem,
		Events:      pub,
		Clock:       adapters.SystemClock{},
		IDs:         adapters.NewULIDGenerator(),
		Codec:       adapters.JSONCodec{},
		Log:         adapters.NewSlogLogger(log),
		Metrics:     adapters.NewMetrics(),
	})

	srv := grpc.NewServer()
	routingv1.RegisterRoutingServiceServer(srv, grpcserver.New(h))

	lis, err := net.Listen("tcp", cfg.Addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", cfg.Addr, err)
	}

	// Health server (liveness/readiness/metrics) on the health port.
	health := velixhealth.New([]velixhealth.ReadinessCheck{
		{Name: "postgres", Check: pool.Ping},
		{Name: "nats", Check: func(ctx context.Context) error {
			if nc.IsClosed() {
				return fmt.Errorf("nats connection closed")
			}
			return nil
		}},
	}, nil)
	health.SetReady(true)
	healthErr := make(chan error, 1)
	go func() { healthErr <- health.ListenAndServe(ctx, cfg.HealthAddr) }()

	serveErr := make(chan error, 1)
	go func() {
		log.Info("routing-server listening", "addr", cfg.Addr, "cell", cfg.Cell, "health", cfg.HealthAddr, "revision", gitRevision)
		serveErr <- srv.Serve(lis)
	}()

	select {
	case <-ctx.Done():
		log.Info("shutdown signal received")
		srv.GracefulStop()
		return shutdown(5 * time.Second)
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

func shutdown(grace time.Duration) error {
	_ = grace
	return nil
}
