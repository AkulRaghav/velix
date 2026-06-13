# Velix Alpha — Quick Start

A runnable end-to-end build of Velix that lets two people register, sign
in, exchange persisted messages, and see them flow across two devices.

## Scope

| Works | Does not yet work |
|---|---|
| Registration with handle + on-device secret | libsignal end-to-end encryption (alpha relays opaque base64 bytes) |
| Sign in with HMAC-SHA256 challenge/response | Multi-device pairing |
| Open 1:1 conversations | Group conversations |
| Send + receive text messages, polled every 2s | Realtime push, voice/video calls, AI |
| Persistence to JSON snapshot on graceful shutdown | Postgres / NATS / Redis / Vault |

The alpha is a self-contained development build. Phase 6 wires production
infrastructure; Phase 7 wires libsignal. **The alpha's protocol shape
(account_id, handle, opaque ciphertext, sealed-sender envelope) matches
the production design**, so the production wiring is a swap, not a rewrite.

## What's in the repo

| Path | Purpose |
|---|---|
| `backend/alpha/` | Self-contained Go HTTP server, stdlib only |
| `backend/alpha/cmd/alpha-server/` | Server binary |
| `backend/alpha/internal/api/` | HTTP+JSON handlers + tests |
| `backend/alpha/internal/store/` | In-memory store + JSON snapshot |
| `backend/alpha/internal/ids/` | Time-prefixed id generator |
| `apps/velix_app/lib/src/presentation/screens/auth/` | Register / sign-in screen |
| `packages/velix_data/lib/src/alpha/` | HTTP client + remote repositories + persisted session |

## Run the backend

```
cd backend/alpha
go run ./cmd/alpha-server
```

Listens on `:8080`. State is in `velix-alpha-state.json`.

Override addr or state path:

```
VELIX_ADDR=:9000 VELIX_STATE_PATH=./state.json go run ./cmd/alpha-server
```

## Run the Flutter app

```
cd apps/velix_app
flutter pub get
flutter run --dart-define=VELIX_ALPHA_URL=http://10.0.2.2:8080
```

- `10.0.2.2` is the Android emulator's loopback to the host machine.
- For iOS simulator: `--dart-define=VELIX_ALPHA_URL=http://127.0.0.1:8080`.
- For desktop / web: `--dart-define=VELIX_ALPHA_URL=http://127.0.0.1:8080`.

## Test messaging end-to-end (two devices)

1. Run the backend on your dev machine.
2. Run the app on Device A, tap **Create account**, pick handle `alice`.
3. The app shows `alice`'s account ID and device secret. Copy them.
4. Run the app on Device B, tap **Create account**, pick handle `bob`.
5. On Device A, tap **Chats**, tap the **+** button, type `bob`, tap **Open**.
6. Send a message from A. Within ~2 s, B's `Chats` list shows the conversation.
7. B opens the conversation; the message is there.

## Test the backend in isolation

Curl-based smoke test:

```sh
# Register Alice (32-byte secret base64)
SECRET=$(openssl rand -base64 32)
ALICE=$(curl -s -X POST http://127.0.0.1:8080/v1/register \
  -H 'Content-Type: application/json' \
  -d "{\"handle\":\"alice\",\"device_secret_b64\":\"$SECRET\"}")
echo "$ALICE"

TOKEN=$(echo "$ALICE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# Me
curl -s http://127.0.0.1:8080/v1/me -H "Authorization: Bearer $TOKEN"
```

## Run the backend tests

```
cd backend/alpha
go test ./...
```

Eight tests, all stdlib-only.

## Run the Dart HMAC test

```
cd packages/velix_data
dart test
```

Three tests against RFC 4231 test vectors for HMAC-SHA256.

## Run the Flutter analyze + smoke test

```
cd apps/velix_app
flutter pub get
flutter analyze
flutter test
```

Smoke test covers `Bootstrap.run`, `VelixButton`, `GlassCard`,
`IdentityCapsule`, `MessageBubble`, and the chat-list provider.

## Architecture map (alpha)

```
[Flutter app]                   [Go alpha-server]
   | register, login              |
   | challenge / hmac              |
   | open conversation             |
   | send / list messages          |
   |  HTTP+JSON  -------------->   |
   |  bearer token                 |  In-memory store
   |                               |  JSON snapshot on shutdown
```

## What graduates from alpha to Phase 6/7

| Alpha → Production |
|---|
| HMAC-SHA256 device secret → Ed25519 identity attestation (libsignal) |
| Opaque base64 body → Sealed-sender ciphertext (Double Ratchet) |
| In-memory store → Postgres per service |
| 2-second polling → NATS JetStream + bidi gRPC stream |
| Single binary → Six services per cell, three cells |
| JSON snapshot → Vault-backed secrets, audit logging, etc. |
```

The alpha's protocol shape is deliberately preserved: account_id, handle,
opaque ciphertext, sealed-sender envelope, idempotency key, ULID-style ids.
Phase 6/7 swaps the implementation, not the contract.

## Known alpha caveats

- No realtime delivery. The client polls every 2 s.
- Sessions are stored in plain JSON on disk (alpha-grade; no secure storage).
- The "encryption" of the body bytes is base64. **The server cannot decode**
  the body content, but a compromised network layer can. Phase 7 is the real
  thing.
- No push notifications.
- No voice / video calling.
- No AI.

These are deliberate alpha cuts — see `docs/phase-11/13-launch-blockers-closure.md`
for the full launch-readiness gate.
