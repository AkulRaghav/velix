# Design — Alpha Stabilization & Validation

## Overview

Document the implemented alpha system and define the work required to make it
build, test, and run end-to-end on a developer machine. **The repository is
the source of truth.** This document describes what exists; it does not
propose new architecture.

The "alpha" is the smallest runnable Velix:

- two users can register
- two users can sign in
- two users can exchange persisted messages
- the backend persists state across restarts (JSON snapshot)
- the Flutter client renders the existing screens against the alpha server
- HMAC-SHA256 identity proof gates login

Production E2EE (libsignal), realtime delivery (NATS), and Phase 6/7 wiring
are out of scope.

## Architecture

### System map

```
+----------------------------+         HTTP + JSON              +------------------------+
|                            |  Authorization: Bearer <token>   |                        |
|     Flutter client         | <------------------------------> |  Go alpha server       |
|     apps/velix_app         |                                  |  backend/alpha         |
|                            |  poll every 2-3 s                |                        |
|  - velix_design (theme)    |                                  |  - net/http only       |
|  - velix_motion            |                                  |  - in-memory store     |
|  - velix_domain            |                                  |  - JSON snapshot       |
|  - velix_data (alpha repos)|                                  |  - HMAC challenge      |
|  - velix_3d                |                                  |                        |
|  - velix_crypto (skeleton) |                                  +------------------------+
+----------------------------+
```

There is no NATS, no Postgres, no Vault, no LiveKit in the alpha. Phase 6/7
adds them; the alpha contract intentionally matches their shape so the swap
is mechanical.

### Flutter client architecture

Layers, top-down:

| Layer | Package | Responsibility |
|---|---|---|
| App shell | `apps/velix_app/lib/src/app.dart` | `MaterialApp.router`, theme bridge |
| Routing | `apps/velix_app/lib/src/router/app_router.dart` | go_router; routes for splash, auth, home, chats, chat, settings, profile, etc. |
| Bootstrap | `apps/velix_app/lib/src/bootstrap/bootstrap.dart` | Loads alpha session; wires remote or in-memory repos |
| DI | `apps/velix_app/lib/src/di/providers.dart` | Riverpod providers; `bootstrapProvider` is overridden in `main.dart` |
| Screens | `apps/velix_app/lib/src/presentation/screens/...` | Splash, auth, chats, chat, home, profile, settings, ai_assistant, etc. |
| Components | `apps/velix_app/lib/src/presentation/components/...` | `VelixButton`, `GlassCard`, `IdentityCapsule`, `MessageBubble`, `VelixLoader` |
| Domain | `packages/velix_domain` | Pure-Dart entities, value objects, repository interfaces, use cases |
| Data | `packages/velix_data` | In-memory repos + alpha HTTP repos |
| Design | `packages/velix_design` | Tokens (Quartz Blue), `VelixTheme`, materials |
| Motion | `packages/velix_motion` | Patterns, scroll physics, haptics |
| 3D | `packages/velix_3d` | Scene widget with 2D fallback |
| Crypto | `packages/velix_crypto` | FFI binding skeleton; throws on call (Phase 7 wires libsignal) |

Strict-cast / strict-inference / strict-raw-types are enabled at the app level
(`apps/velix_app/analysis_options.yaml`).

### Go backend alpha architecture

Module path: `github.com/velix/backend/alpha`. **Standard library only.**
Pinned Go version: 1.22 (uses `mux.HandleFunc("METHOD /path/{id}")`).

Layout:

```
backend/alpha/
  go.mod
  README.md
  cmd/alpha-server/main.go         entrypoint, signal handling, snapshot save on exit
  internal/api/api.go              HTTP+JSON handlers + middleware
  internal/api/api_test.go         e2e API test using httptest
  internal/store/store.go          in-memory store + JSON load/save
  internal/ids/ids.go              opaque base32 id generator
```

Workspace: `backend/go.work` lists only `./alpha`. The Phase 6 service modules
under `backend/services/...` are not part of this build.

### Server lifecycle

`cmd/alpha-server/main.go`:

1. Reads `VELIX_ADDR` (default `:8080`) and `VELIX_STATE_PATH` (default `velix-alpha-state.json`).
2. Creates `store.New()`, calls `store.Load(statePath)` (missing file is not an error).
3. Constructs `api.Server{Store, Logger}`.
4. Starts an `http.Server` with sensible timeouts on a goroutine.
5. Waits for SIGINT/SIGTERM, calls `Shutdown(5s)`, then `store.Save(statePath)`.

### Middleware chain

`api.Server.Handler()` returns:

```
withCORS( withLogging( mux ) )
```

- CORS: permissive (`*`) for local development.
- Logging: method, path, status, duration via `*log.Logger`.
- Auth: per-route, applied via `requireAuth(handler)` adapter for protected routes.

### Concurrency model

`store.Store` holds a single `sync.RWMutex`. All reads use `RLock`, all writes
`Lock`. Volume is small; alpha is dev-grade.

## Components and Interfaces

### Bootstrap behavior

`Bootstrap.run({Uri? alphaUri, String sessionPath})`:

1. Loads `AlphaSession` from `sessionPath` (default `velix_alpha_session.json`).
2. If a session exists → wires `RemoteIdentityRepository`, `RemoteConversationRepository`, `RemoteMessageRepository` against `AlphaApiClient(baseUri: alphaUri ?? defaultAlphaUri())`.
3. If no session → wires `InMemory*` repositories with empty seed and a guest stub identity, so the auth screen is reachable.
4. Returns a `BootstrapResult` (immutable; held by `bootstrapProvider`).

`defaultAlphaUri()` resolves to `http://10.0.2.2:8080` on Android, `http://127.0.0.1:8080` elsewhere; both can be overridden via `--dart-define=VELIX_ALPHA_URL=...`.

### Splash → auth/home redirect

`SplashScreen` reads `bootstrapProvider` after a 800 ms cinematic hold and routes:

- `boot.session != null` → `/home`
- `boot.session == null` → `/auth`

### Auth screen

`/auth` is a two-tab screen:

- **Create account.** Generates a 32-byte device secret via `AlphaApiClient.generateDeviceSecret`. Calls `register(handle, deviceSecret)`. On success persists the session via `AlphaSessionStore.save` and shows a dialog displaying the account ID + device secret base64 for the user to copy.
- **Sign in.** Caller enters account ID + device-secret base64. Client fetches a challenge nonce, computes HMAC-SHA256 in pure Dart, calls `login`. On success persists the session. User is asked to restart the app so the cold-start picks up the new session and wires the remote repositories.

### Chats screen

Chat list driven by `chatListProvider` → `ConversationRepository.watchAll`. The
header includes a `+` button that opens a "Start a conversation" dialog; the
dialog calls `AlphaApiClient.lookup(handle)` then `RemoteConversationRepository.openWith`.

### Chat screen

Uses the Riverpod use cases `sendMessageProvider` and
`messagesProvider(conversationId)`. The remote message repo polls every 2 s while
the screen is mounted.

### Authentication flow

```
                    Client                                  Server
                    ------                                  ------
register:           POST /v1/register
                    handle, device_secret_b64 ----->        validate handle regex
                                                            decode 32-byte secret
                                                            generate account_id (ULID-ish)
                                                            create account
                                                            issue 30-day bearer token
                          <----------- account_id, token

challenge:          GET /v1/challenge?account_id=
                                                  ----->    rand(32) → nonce
                                                            store challenge (TTL 2 min)
                          <----------- nonce_b64

login:              compute hmac = HMAC-SHA256(secret, nonce)
                    POST /v1/login
                    account_id, nonce_b64, hmac_b64 ----->  consume challenge by nonce
                                                            recompute HMAC with stored secret
                                                            constant-time compare (hmac.Equal)
                                                            issue fresh 30-day token
                          <----------- token, expires_at
```

Alpha-grade. Phase 7 swaps in libsignal-backed Ed25519 attestation. The
contract shape (`account_id`, `handle`, signature-of-nonce, bearer token)
is preserved so the swap is mechanical.

### Messaging flow

```
A opens conversation:    POST /v1/conversations
                         peer_account_id, title -->   upsertConversationFor(A, B)
                                                      (idempotent: same pair → same id)
                         <-- conversation { id, peer_account_id, title, ... }

A sends message:         POST /v1/conversations/{id}/messages
                         kind, ciphertext_b64, preview --> verify A is member
                                                            create message row
                                                            update conversation.lastActive + preview
                         <-- message { id, sender_id, ciphertext_b64, sent_at }

B polls (every 2 s):     GET /v1/conversations/{id}/messages
                                                  --> verify B is member
                         <-- messages: [...]
```

The body is base64. **The server never decodes it.** Client maps base64 ↔
plaintext using `utf8.encode` / `utf8.decode` for the alpha; Phase 7 wraps
the bytes with libsignal at the client edge so the server still sees opaque.

### Polling / sync flow

The alpha has no realtime push. The Flutter client polls:

| Stream | Source | Interval |
|---|---|---|
| `RemoteConversationRepository.watchAll()` | `GET /v1/conversations` | 3 s while ≥1 watcher |
| `RemoteMessageRepository.watch(id)` | `GET /v1/conversations/{id}/messages` | 2 s per active conversation |

Both repositories ref-count watchers and stop the timer when the count drops
to zero. Errors are swallowed (UI keeps the cached state).

### HMAC identity-proof flow

Pure-Dart HMAC-SHA256 lives in
`packages/velix_data/lib/src/alpha/alpha_api_client.dart`:

- `AlphaApiClient.generateDeviceSecret()` → 32 random bytes via `Random.secure()`.
- `AlphaApiClient.hmacSha256(key, msg)` → 32 bytes; verified against RFC 4231 cases 1, 2, 3 by `packages/velix_data/test/alpha_hmac_test.dart`.

Server-side verification uses Go's `crypto/hmac` and `hmac.Equal` for
constant-time comparison.

The HMAC binds to one challenge: a successful login consumes the challenge
(`store.ConsumeChallenge(nonce)` deletes the row). Re-using the same nonce
returns 401.

### API contracts

All routes under `/v1/`. JSON request and response. Bearer token in
`Authorization: Bearer <token>` for protected routes.

| Method | Path | Auth | Body in / out |
|---|---|---|---|
| GET | `/v1/healthz` | none | `{ status, time }` |
| GET | `/v1/readyz` | none | `{ status, time }` |
| POST | `/v1/register` | none | `{ handle, device_secret_b64 }` → `{ account_id, handle, token, expires_at }` |
| GET | `/v1/challenge?account_id=` | none | → `{ nonce_b64, expires_at }` |
| POST | `/v1/login` | none | `{ account_id, nonce_b64, hmac_b64 }` → `{ token, expires_at }` |
| GET | `/v1/me` | bearer | → `{ account_id, handle }` |
| GET | `/v1/users/lookup?handle=` | bearer | → `{ account_id, handle }` |
| GET | `/v1/conversations` | bearer | → `{ conversations: [...] }` |
| POST | `/v1/conversations` | bearer | `{ peer_account_id, title }` → `{ id, peer_account_id, title, last_active_at, last_message_preview }` |
| GET | `/v1/conversations/{id}/messages` | bearer | → `{ messages: [...] }` |
| POST | `/v1/conversations/{id}/messages` | bearer | `{ kind, ciphertext_b64, preview }` → `{ id, conversation_id, sender_id, kind, ciphertext_b64, sent_at }` |

Errors return `{ "error": "<message>" }` with the appropriate HTTP status.

Bounds:

- handle: 3–32 chars, `[a-zA-Z0-9._-]`
- device secret: exactly 32 bytes (44 chars base64)
- HMAC: exactly 32 bytes
- ciphertext per message: ≤ 256 KB request body
- preview: truncated to 96 chars server-side

## Data Models

### Server (in-memory, snapshotted to JSON)

| Type | Fields | Notes |
|---|---|---|
| Account | id, handle, identity_pubkey (= device secret in alpha), created_at | unique on handle |
| Session | token, account_id, issued_at, expires_at | 30-day TTL |
| Challenge | account_id, nonce (32B), issued_at, expires_at (2 min) | one-shot, consumed on login |
| Conversation | id, member_a, member_b, title, created_at, last_active, last_message_preview | one row per ordered pair, but `UpsertConversationFor` returns the same row regardless of order |
| Message | id, conversation_id, sender_id, kind, ciphertext_b64, sent_at | append-only |

### Snapshot JSON layout

```
{
  "accounts":      { account_id: Account },
  "handles_to_account_id": { handle: account_id },
  "sessions":      { token: Session },
  "conversations": { conversation_id: Conversation },
  "messages_by_conversation": { conversation_id: [Message, ...] },
  "challenges_by_nonce": { hex(nonce): Challenge }
}
```

- `Load(path)` is no-op when the file is missing.
- `Save(path)` writes to `<path>.tmp` and renames atomically.
- `Save` runs once on graceful shutdown. There is no incremental WAL.
- Restart safety: a crash before save loses the in-memory delta.

### Client persistence (`AlphaSession`)

Stored at the path passed to `Bootstrap.run` (default `velix_alpha_session.json`).
Contains `account_id`, `handle`, `token`, `identity_public_key`,
`identity_private_key` (both equal to the device secret in the alpha;
Phase 7 splits them properly).

## Correctness Properties

### Property 1: Idempotent conversation upsert

`UpsertConversationFor(A, B)` and `UpsertConversationFor(B, A)` return the
same conversation id.

**Validates: Requirements 7.1, 7.2**

### Property 2: Bounded attack surface

Server validates handle regex, decodes exactly 32-byte device secret,
decodes exactly 32-byte HMAC, bounds request bodies (4 KB for auth bodies,
256 KB for messages).

**Validates: Requirements 1.5, 2.3, 2.4**

### Property 3: Single-use challenge

`ConsumeChallenge` deletes the row before recomputing HMAC. A replay
returns 401.

**Validates: Requirements 2.2**

### Property 4: Constant-time HMAC compare

Server uses `hmac.Equal`, not `bytes.Equal`.

**Validates: Requirements 2.2**

### Property 5: Membership gate

`IsMember(conversation_id, account_id)` is checked before list / send.
Non-member receives 403.

**Validates: Requirements 2.2, 7.5**

### Property 6: HMAC interop with RFC 4231

Pure-Dart HMAC-SHA256 matches RFC 4231 vectors 1, 2, 3 and the Go
`crypto/hmac` output.

**Validates: Requirements 3.2, 3.3, 3.4**

## Error Handling

| Surface | Strategy |
|---|---|
| Server input validation | Returns `{ "error": "<message>" }` with `400 BadRequest`. |
| Auth failures | `401 Unauthorized` for missing / invalid / expired bearer; `401` for HMAC mismatch; `404 NotFound` for unknown account. |
| Conflicts | `409 Conflict` for handle taken. |
| Forbidden | `403 Forbidden` for non-member access. |
| Server internal | `500 Internal` with a generic message; details logged server-side. |
| Client polling | Errors are swallowed; the cached list stays. UI does not show transient network errors during background refresh. |
| Client auth flow | Auth-screen catches exceptions and surfaces `e.toString()` in the panel below the form. |

## Testing Strategy

Three command targets must pass.

### 1. Backend unit + integration

```
cd backend/alpha
go vet ./...
go build ./...
go test ./...
```

Covered:

- `TestE2E_RegisterLoginSendList` — register 2 accounts, login HMAC, lookup, open conversation, send + list message, third-party 403.
- `TestRegister_RejectsBadHandle` — 5 invalid handles → 400.
- `TestRegister_RejectsBadSecret` — non-base64 + short secret → 400.
- `TestSnapshotPersistence` — JSON round-trip preserves account.

### 2. Dart package tests (alpha HMAC)

```
cd packages/velix_data
dart pub get
dart test
```

Covered:

- `AlphaApiClient.hmacSha256` against RFC 4231 test cases 1, 2, 3.

### 3. Flutter analyze + smoke test

```
cd apps/velix_app
flutter pub get
flutter analyze
flutter test
```

Covered (`apps/velix_app/test/widget_smoke_test.dart`):

- `Bootstrap.run` with missing session path → in-memory mode, identity not null.
- `VelixButton`, `GlassCard`, `IdentityCapsule`, `MessageBubble` smoke renders.
- `chatListProvider` streams `List<Conversation>`.

### Manual two-device validation

```
# terminal 1
cd backend/alpha && go run ./cmd/alpha-server

# terminals 2 + 3 (each a different emulator/device)
cd apps/velix_app && flutter run \
  --dart-define=VELIX_ALPHA_URL=http://10.0.2.2:8080
```

A registers as `alice`, B registers as `bob`. A taps **+** in Chats, types
`bob`, opens conversation, sends a message. Within ~2 s, B sees the message.

### Acceptance criteria

The alpha is **runnable** when, on a developer machine with the toolchains
installed:

1. `cd backend/alpha && go test ./...` exits 0.
2. `cd packages/velix_data && dart test` exits 0.
3. `cd apps/velix_app && flutter analyze` exits 0.
4. `cd apps/velix_app && flutter test` exits 0.
5. `cd backend/alpha && go run ./cmd/alpha-server` listens on `:8080` and responds 200 to `GET /v1/healthz`.
6. `flutter run --dart-define=VELIX_ALPHA_URL=...` shows the splash, redirects to `/auth`, allows registration, persists the session, and on restart lands on `/home`.
7. Two devices can register distinct handles, exchange a message, and the message appears on the other device within 5 s.

The alpha is **stable** when, after a graceful server stop and restart,
existing accounts can still sign in via challenge/HMAC and prior conversations
remain visible.

### Out of scope

These belong to later phases and must not be touched as part of alpha
stabilization:

- libsignal Rust FFI bodies (Phase 7).
- Cell topology, Argo CD, Vault, NATS, Postgres (Phase 6 / Phase 10).
- Voice/video calling (Phase 6).
- AI features (Phase 8).
- Push notifications (APNs / FCM).
- Stories / feed.
- Audits, legal, store onboarding (Phase 11 launch gate).

### Risks tracked

| Risk | Mitigation |
|---|---|
| `flutter pub get` requires network for `flutter_riverpod`, `go_router`, `meta`, `flutter_lints` | Documented; alpha cannot run fully air-gapped. |
| Polling at 2 s is wasteful; not realtime | Acceptable for alpha; Phase 6 wires NATS push. |
| JSON snapshot lost on hard crash before `Save` | Acceptable for alpha; Phase 6 wires Postgres. |
| Pure-Dart SHA-256 is slow vs platform crypto | Used only on login (1 hash per session); negligible. |
| Strict-cast / require_trailing_commas may surface on `flutter analyze` | Track in tasks; fix any found violations. |
| Toolchains absent from the agent's environment | Validation runs on developer machines; agent inspects code statically. |
