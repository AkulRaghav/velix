# Velix

**Privacy-first, end-to-end encrypted social messaging — built with a Flutter client, a Go microservice backend, and a Rust cryptographic core.**

Velix is a full-stack messaging platform engineered to production standards: a polished Flutter app over a custom design system, six Go gRPC microservices with real PostgreSQL persistence and NATS JetStream eventing, and a libsignal-based Rust crypto core exposed to Dart via FFI. It ships with a runnable alpha you can stand up locally end-to-end.

---

## Highlights

- **End-to-end architecture** — Flutter client → Go gRPC services → PostgreSQL + NATS JetStream + Redis, with a Rust/FFI cryptographic core.
- **Six production microservices** — identity, routing, media, push, call, notifier. Each has real pgx-backed stores, transactional writes, a gRPC adapter, bearer-token auth enforcement, and Kubernetes-ready health/readiness/metrics endpoints.
- **Custom design system** — `velix_design`, `velix_motion`, and `velix_3d` packages implement Apple-grade tokens (OKLCH color, WCAG-verified contrast), a spring-physics motion grammar, glass materials, and a 3D scene system with 2D fallbacks.
- **Offline-first client** — clean architecture (domain / data / presentation), Riverpod state, repository pattern with in-memory and remote (HTTP) implementations, and a persisted session.
- **Verified, not just written** — unit tests, in-memory gRPC integration tests (bufconn), real-PostgreSQL integration tests, and a real-NATS publish/consume round-trip. The full backend has been booted and exercised end-to-end against live Postgres + NATS.
- **Real infrastructure as code** — Helm charts (lint + template clean), Terraform modules (validate clean), Argo CD ApplicationSet/AppProject, and GitHub Actions CI across all layers.

## Tech stack

| Layer | Technology |
|---|---|
| Client | Flutter 3 / Dart 3, Riverpod, go_router, custom design system |
| Cryptography | Rust core (libsignal) via Dart FFI; XChaCha20-Poly1305, Argon2id, Ed25519 |
| Backend | Go 1.22+, gRPC, protobuf (buf), multi-module workspace |
| Persistence | PostgreSQL 16 (pgx), Redis 7 |
| Event spine | NATS JetStream |
| Object store | Cloudflare R2 (S3-compatible) |
| Realtime media | LiveKit SFU with E2EE Insertable Streams |
| Infra | Terraform, Kubernetes, Helm, Argo CD, GitHub Actions |
| Observability | structured slog logging with PII filtering, Prometheus-style metrics |

## Repository layout

```
apps/velix_app          Flutter application (screens, routing, DI, bootstrap)
packages/
  velix_design          Design tokens, materials, typography, color
  velix_motion          Spring-physics motion + haptics
  velix_3d              3D scene widget + 2D fallbacks
  velix_domain          Entities, use cases, repository interfaces
  velix_data            Repository implementations + HTTP alpha client
  velix_crypto          Dart FFI binding to the Rust crypto core
backend/
  alpha                 Self-contained HTTP/JSON alpha server (stdlib only)
  proto                 Protobuf contracts + generated Go stubs
  services/             routing, identity, media, push, call, notifier
  pkg/                  Shared libs: velixsql(pgx), velixobs(slog), velixnatsjs,
                        velixhealth, velixgrpcauth, velixtoken, velixerr, velixctx
cryptocore              Rust cryptographic core (FFI surface + audited primitives)
infra/                  Helm charts, Terraform, Argo CD, monitoring, dev stack
docs/                   Architecture, design, and engineering documentation
```

## Quick start

### Run the alpha end-to-end (no cloud required)

```bash
# 1. Backend (Go stdlib only — compiles offline)
cd backend/alpha
go run ./cmd/alpha-server          # listens on :8080

# 2. Flutter app (Android emulator → host loopback)
cd apps/velix_app
flutter pub get
flutter run --dart-define=VELIX_ALPHA_URL=http://10.0.2.2:8080
```

Register two accounts, open a conversation by handle, and exchange messages that persist across both devices. See `ALPHA.md` for the full walkthrough.

### Run the production services locally

```bash
# Postgres + NATS + Redis (Docker) — or native installs, see infra/dev/README.md
docker compose -f infra/dev/docker-compose.yml up -d
./infra/dev/migrate.sh

cd backend/services/routing
VELIX_DSN="postgres://velix:velix@localhost:5432/velix_routing?sslmode=disable" \
VELIX_NATS_URL="nats://localhost:4222" \
GOWORK=off go run ./cmd/routing-server
```

## Engineering highlights

- **Clean, layered architecture** on both client (domain/data/presentation) and backend (handlers / stores / adapters behind interfaces), making every dependency a swappable seam.
- **Auth posture enforced fleet-wide** — a shared gRPC interceptor verifies HMAC-SHA256 bearer tokens and injects the principal; per-method `AUTH_NONE` / `AUTH_CLIENT` / `AUTH_INTERNAL` postures.
- **Sealed-sender-aware routing** — the realtime path stores opaque ciphertext and never learns the sender from envelope metadata.
- **Idempotency + transactions** — every write runs in a serializable transaction with an idempotency cache; the one-time-prekey claim uses `FOR UPDATE SKIP LOCKED`.
- **Performance-conscious UI** — per-cell `RepaintBoundary`s, reduce-motion support folded into `MediaQuery`, configurable accessibility gesture thresholds.
- **Reproducible builds** — pinned dependencies, deterministic proto generation, distroless non-root container images.

## Testing & validation

| Surface | What runs |
|---|---|
| Flutter app | `flutter analyze` (0 issues), widget + provider tests |
| Dart packages | `dart test` (design, data, domain) |
| Go services | `go test` per module, bufconn gRPC integration, real-Postgres integration (build-tagged) |
| Event bus | real NATS JetStream publish/consume round-trip |
| Crypto core | `cargo test`, `clippy`, `fmt` |
| Infra | `helm lint`/`template`, `terraform fmt`/`validate` |

CI (`.github/workflows/`) runs these across backend, Flutter, and cryptocore on every push.

## Status

The architecture and internal engineering are complete and verified. Remaining work to a public 1.0 is external: third-party security/privacy audits, provider credentials (R2, LiveKit, APNs/FCM), provisioned cloud cells, app-store onboarding, and mandatory beta soak periods. See `docs/` for the full roadmap.

## License

Apache-2.0.
