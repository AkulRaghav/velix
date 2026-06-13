// Command media-server runs the MediaService.
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

	mediav1 "github.com/velix/backend/proto/gen/go/velix/media/v1"
	"github.com/velix/backend/pkg/velixgrpcauth"
	"github.com/velix/backend/pkg/velixhealth"
	"github.com/velix/backend/pkg/velixnatsjs"
	"github.com/velix/backend/pkg/velixtoken"
	"github.com/velix/backend/pkg/velixobsslog"
	"github.com/velix/backend/pkg/velixsqlpgx"
	"github.com/velix/backend/services/media/internal/adapters"
	"github.com/velix/backend/services/media/internal/grpcserver"
	"github.com/velix/backend/services/media/internal/handlers"
	"github.com/velix/backend/services/media/internal/pgxstore"
)

type Config struct {
	Addr      string
	HealthAddr string
	DSN       string
	NATSURL   string
	R2Endpoint string
	R2Bucket  string
	TokenKey  string
	LogLevel  string
}

func loadConfig() Config {
	return Config{
		Addr:       env("VELIX_ADDR", ":8080"),
		HealthAddr: env("VELIX_HEALTH_ADDR", ":8081"),
		DSN:        env("VELIX_DSN", ""),
		NATSURL:    env("VELIX_NATS_URL", ""),
		R2Endpoint: env("VELIX_R2_ENDPOINT", ""),
		R2Bucket:   env("VELIX_R2_BUCKET", ""),
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
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if err := run(ctx, loadConfig()); err != nil {
		fmt.Fprintln(os.Stderr, "media-server fatal:", err)
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

	pub, nc, err := velixnatsjs.Connect(ctx, cfg.NATSURL, "VELIX_MEDIA", []string{"velix.media.>"})
	if err != nil {
		return err
	}
	defer nc.Close()

	h := handlers.NewHandlers(handlers.Deps{
		TxRunner: pool,
		Media:    pgxstore.NewMediaStore(),
		Storage:  adapters.NewR2Storage(cfg.R2Endpoint, cfg.R2Bucket),
		Events:   pub,
		Clock:    adapters.SystemClock{},
		IDs:      adapters.NewULIDGenerator(),
		Log:      log,
		Metrics: &handlers.Metrics{
			UploadsCreated:   meter.Counter("media_uploads_created"),
			UploadsFinalized: meter.Counter("media_uploads_finalized"),
			DownloadsIssued:  meter.Counter("media_downloads_issued"),
			Deleted:          meter.Counter("media_deleted"),
		},
	})

	srv := grpc.NewServer(
		grpc.UnaryInterceptor(velixgrpcauth.UnaryInterceptor(
			velixtoken.NewVerifier([]byte(cfg.TokenKey)),
			velixgrpcauth.StaticPostures(nil), // all methods PostureClient
		)),
	)
	mediav1.RegisterMediaServiceServer(srv, grpcserver.New(h))

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
		log.Info(ctx, "media-server listening", "addr", cfg.Addr, "health", cfg.HealthAddr, "revision", gitRevision)
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
