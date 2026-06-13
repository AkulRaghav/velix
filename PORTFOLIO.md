# Velix — Portfolio & Recruiter Guide

A concise, recruiter-facing summary of what Velix is, how it's engineered, and how to talk about it.

---

## One-line pitch

> Velix is a privacy-first, end-to-end encrypted messaging platform — a Flutter client over six Go gRPC microservices and a Rust cryptographic core — built and validated to production standards.

## What it demonstrates

- Full-stack ownership: mobile client, backend microservices, cryptography, and infrastructure.
- Production engineering discipline: layered architecture, dependency injection, interface seams, transactions, idempotency, auth enforcement, observability, and CI.
- Real verification: not just code that compiles — services booted and exercised end-to-end against live PostgreSQL and NATS JetStream.

## Architecture overview

```
┌────────────────────────────────────────────────────────────┐
│  Flutter app (clean architecture)                            │
│  presentation → domain (use cases) → data (repositories)     │
│  Riverpod · go_router · custom design system (3 packages)    │
└───────────────┬──────────────────────────────────────────────┘
                │ HTTP/JSON (alpha)  ·  gRPC (production)
┌───────────────▼──────────────────────────────────────────────┐
│  Go backend — six gRPC microservices                          │
│  identity · routing · media · push · call · notifier          │
│  each: handlers → stores (pgx) → adapters, behind interfaces  │
│  shared libs: sql · obs · nats · health · grpcauth · token    │
└──────┬─────────────────┬───────────────────┬─────────────────┘
       │                 │                   │
   PostgreSQL 16      NATS JetStream       Redis 7
   (pgx, txns)        (event spine)        (presence/TTL)
                │
┌───────────────▼──────────────────────────────────────────────┐
│  Rust cryptographic core (libsignal) — Dart FFI               │
│  Ed25519 · X3DH · Double Ratchet · XChaCha20-Poly1305 · Argon2│
└────────────────────────────────────────────────────────────┘
```

## Feature list

**Client**
- Onboarding flow with 3D scenes + 2D fallbacks and animated step progression
- Cryptographic-identity registration and HMAC challenge/response sign-in
- 1:1 conversations with live polling, optimistic UI, and search
- Profile surface with real account stats (conversations, member-since, devices)
- Settings with a full accessibility panel: reduce motion, high contrast, configurable gesture thresholds
- Calm-by-design empty states, loading skeletons, and error states throughout

**Backend**
- Identity: account creation, device attestation, prekey publish/fetch (X3DH), HMAC token issuance
- Routing: realtime envelope send with idempotency + async JetStream fan-out (sealed-sender aware)
- Media: presigned upload/download lifecycle (R2)
- Push / Call / Notifier: token management, LiveKit brokering, APNs/FCM delivery
- Fleet-wide bearer-token auth enforcement; Kubernetes health/readiness/metrics

## Tech stack summary

Flutter 3 / Dart 3 · Riverpod · go_router · Go 1.22+ · gRPC / protobuf (buf) · PostgreSQL 16 (pgx) · NATS JetStream · Redis 7 · Rust (libsignal, RustCrypto) · Dart FFI · Terraform · Kubernetes · Helm · Argo CD · GitHub Actions.

## Engineering highlights (the things worth pointing at)

1. **Multi-module Go workspace** with shared libraries behind interfaces (`velixsql`, `velixobs`, `velixnats`, `velixhealth`, `velixgrpcauth`, `velixtoken`) — each service depends on seams, not concretions.
2. **gRPC auth interceptor** with per-method posture enforcement, verified live (unauthenticated calls rejected before reaching handlers).
3. **Transactional, idempotent writes** — serializable transactions, idempotency cache, `FOR UPDATE SKIP LOCKED` prekey claiming.
4. **Real integration testing** — bufconn in-memory gRPC tests, build-tagged Postgres integration tests, and a live NATS JetStream round-trip.
5. **Custom design system** — OKLCH color tokens with WCAG-verified contrast, spring-physics motion, glass materials, accessibility folded into `MediaQuery`.
6. **Infrastructure as code, validated** — Helm (lint/template clean), Terraform (validate clean), Argo CD GitOps, distroless reproducible container images.

## Resume bullet points (copy-ready)

- Built a full-stack end-to-end encrypted messaging platform: a Flutter client, six Go gRPC microservices, and a Rust cryptographic core exposed via Dart FFI.
- Designed a multi-module Go backend with interface-based seams (SQL, eventing, auth, observability), enabling unit, in-memory gRPC, and real-PostgreSQL integration testing.
- Implemented fleet-wide gRPC bearer-token authentication with per-method posture enforcement, verified against live services.
- Engineered transactional, idempotent message routing with NATS JetStream fan-out, validated end-to-end against real PostgreSQL and NATS.
- Authored a custom Flutter design system (OKLCH color with WCAG-verified contrast, spring-physics motion, accessibility controls) and an offline-first clean architecture.
- Produced production infrastructure as code (Helm, Terraform, Argo CD) and multi-stack CI, validated with the real toolchains.

## Recruiter talking points

- *"Why is this more than a tutorial app?"* — It's a multi-service distributed system with real persistence, eventing, and auth, verified by booting the services against live Postgres and NATS, not just unit tests.
- *"What was the hardest part?"* — Designing clean interface seams so the same handlers run against fakes in unit tests, an in-memory gRPC transport in integration tests, and real Postgres in CI — without changing business logic.
- *"What shows production maturity?"* — Idempotency, serializable transactions, health/readiness probes, structured PII-filtered logging, reproducible distroless builds, and validated IaC.
- *"What's the privacy story?"* — End-to-end encryption with a libsignal Rust core, sealed-sender-aware routing (the server never learns the sender from metadata), and on-device-first AI with per-query consent.

## How to demo in 90 seconds

1. `go run ./backend/alpha/cmd/alpha-server`
2. `flutter run` the app on two emulators/devices.
3. Register `alice` and `bob`, open a conversation, send a message — watch it appear on both within ~2s.
4. Show the accessibility settings, the calm empty states, and the splash/onboarding motion.
5. Open the backend: show the six services, the shared libs, and `go test` + the real-Postgres integration tests.

## Compared to typical student projects

Most student projects are a single app talking to one database (or Firebase) with little testing and no infrastructure. Velix is a **distributed system**: multiple independently-deployable services, a custom cryptographic core, a bespoke design system, real integration testing against live infrastructure, and validated production IaC — the shape of work expected from a mid-level engineer, not a beginner.
