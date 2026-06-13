# Phase 5 — Frontend Architecture & Production Flutter Application

Status: in progress. Gates Phase 6.

## What ships

The production Flutter codebase: clean architecture, offline-first persistence, secure key storage, multi-device sync foundations, full integration of Phase 2 design tokens, Phase 3 3D contracts, Phase 4 motion grammar.

## Locked posture

- **Stack.** Flutter 3.22+, Dart 3.4+. Riverpod 2 (codegen). go_router 14. drift 2 + sqlcipher_flutter_libs. flutter_secure_storage. OpenTelemetry Dart.
- **Architecture.** Three-layer clean architecture, packaged. Domain is pure Dart, no Flutter dependency. Imports flow only inward.
- **State.** Riverpod with `family` for per-conversation state, `keepAlive` selectively.
- **Routing.** go_router with typed routes; every push uses `VelixPageRoute` for the lateral motion + edge-swipe-back inheritance.
- **Persistence.** drift over SQLCipher. Local DB encrypted at rest with a hardware-backed key. Offline-first: writes commit locally, sync queue replays.
- **Errors.** `Result<S, E>` across layer boundaries. `AppError` taxonomy. Errors never carry PII into telemetry.
- **Telemetry.** OTel via `velix_telemetry`. Aggregate-only, scrubbed, sampled.

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Architecture Overview](./00-architecture-overview.md) | Tree, layers, bootstrap, banned patterns |
| 01 | [Clean Architecture](./01-clean-architecture.md) | Three layers in detail, package boundaries |
| 02 | [State Management](./02-state-management.md) | Riverpod patterns, scoping, testing |
| 03 | [Routing](./03-routing.md) | go_router, typed routes, deep links |
| 04 | [Offline-First Storage](./04-offline-first-storage.md) | drift, SQLCipher, sync queue |
| 05 | [Secure Key Storage](./05-secure-key-storage.md) | OS keychain, key hierarchy |
| 06 | [Multi-Device Sync Foundation](./06-multi-device-sync-foundation.md) | Pairing, history transfer, queue |
| 07 | [Error Handling & Telemetry](./07-error-and-telemetry.md) | Result types, taxonomy, OTel |
| 08 | [Screen Implementation Plan](./08-screen-implementation-plan.md) | Tier A/B/C plan, component list |
| 09 | [Phase 5 Audit](./09-phase-5-audit.md) | Self-review, gates Phase 6 |

## Reference implementation

```
apps/velix_app/                 ← the binary
packages/velix_design/          ← Phase 2 (no changes)
packages/velix_3d/              ← Phase 3 (no changes)
packages/velix_motion/          ← Phase 4 (no changes)
packages/velix_domain/          ← Phase 5 — entities, use cases, repository interfaces
packages/velix_data/            ← Phase 5 — drift, secure storage, gateways, repositories
packages/velix_crypto/          ← Phase 5 — libsignal Dart FFI surface (stubs)
packages/velix_telemetry/       ← Phase 5 — OTel SDK wrapper
```

## Reading order

If you have ten minutes: 00 → 08 → 09.
If you're implementing a screen: 08 → 02 → 03 → component contracts in Phase 2 doc 09.
If you're auditing: 09 → 07 → 04 → 05 → 01.
