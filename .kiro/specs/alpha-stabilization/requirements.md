# Requirements Document

## Introduction

Make the implemented Velix alpha **runnable, testable, and persistent on a
developer machine**. No new features. No new architecture. The existing repo
is the source of truth.

Personas:

- **Alpha tester (developer).** Wants to run the backend, register two
  accounts on two devices, and exchange messages without recompiling on
  every restart.
- **Continuing engineer.** Wants `flutter test`, `dart test`, and
  `go test ./...` to all pass, so the next change can rely on a green baseline.

## Glossary

- **Alpha session.** Persisted JSON containing the device's account id,
  handle, bearer token, and device secret. Path: `velix_alpha_session.json`.
- **Device secret.** 32 random bytes generated on the client at registration;
  used as the HMAC key for the challenge / login proof.
- **Bearer token.** Opaque 32-byte random token issued by the server on
  registration or login. 30-day TTL.
- **State snapshot.** JSON file written by the server on graceful shutdown;
  reloaded on next start. Path: `velix-alpha-state.json`.

## Requirements

### Requirement 1: Compile cleanly

**User Story:** As a continuing engineer, I want the Flutter, Dart, and Go codebases to compile and analyze without errors so that I can change one piece without breaking another.

#### Acceptance Criteria

1. WHEN I run `cd backend/alpha && go vet ./...` THEN the command SHALL exit 0 with no output to stderr.
2. WHEN I run `cd backend/alpha && go build ./...` THEN the command SHALL produce a binary in the working directory or `go-build` cache without errors.
3. WHEN I run `cd packages/velix_data && dart pub get` THEN the command SHALL succeed against the package's pubspec.
4. WHEN I run `cd apps/velix_app && flutter pub get` THEN the command SHALL succeed against the app's pubspec.
5. WHEN I run `cd apps/velix_app && flutter analyze` THEN the command SHALL exit 0 with no `error` or `warning` severity diagnostics.

**Source of truth.** `backend/alpha/go.mod`, `apps/velix_app/pubspec.yaml`, `packages/velix_data/pubspec.yaml`, `apps/velix_app/analysis_options.yaml`.

### Requirement 2: Backend tests pass

**User Story:** As a continuing engineer, I want the backend tests to verify the registration, login, lookup, conversation, and messaging endpoints so that future changes are caught before they ship.

#### Acceptance Criteria

1. WHEN I run `cd backend/alpha && go test ./...` THEN the command SHALL exit 0.
2. WHEN the test `TestE2E_RegisterLoginSendList` executes THEN it SHALL register two accounts, perform an HMAC-validated login, open a conversation, send a message, list messages, and verify a non-member receives 403.
3. WHEN the test `TestRegister_RejectsBadHandle` executes THEN it SHALL verify that 5 invalid handles return 400.
4. WHEN the test `TestRegister_RejectsBadSecret` executes THEN it SHALL verify that non-base64 and short secrets return 400.
5. WHEN the test `TestSnapshotPersistence` executes THEN it SHALL verify a `store.Save` / `store.Load` round-trip preserves an account.

**Source of truth.** `backend/alpha/internal/api/api_test.go`, `backend/alpha/internal/store/store.go`.

### Requirement 3: Dart HMAC tests pass

**User Story:** As a continuing engineer, I want the pure-Dart HMAC-SHA256 implementation to match RFC 4231 vectors so that login interop with the Go server cannot silently drift.

#### Acceptance Criteria

1. WHEN I run `cd packages/velix_data && dart test` THEN the command SHALL exit 0.
2. WHEN the test "RFC 4231 test case 1" executes THEN `AlphaApiClient.hmacSha256(0x0b*20, "Hi There")` SHALL equal `b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7`.
3. WHEN the test "RFC 4231 test case 2" executes THEN `hmacSha256("Jefe", "what do ya want for nothing?")` SHALL equal `5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843`.
4. WHEN the test "RFC 4231 test case 3" executes THEN `hmacSha256(0xaa*20, 0xdd*50)` SHALL equal `773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe`.

**Source of truth.** `packages/velix_data/lib/src/alpha/alpha_api_client.dart`, `packages/velix_data/test/alpha_hmac_test.dart`.

### Requirement 4: Flutter smoke test passes

**User Story:** As a continuing engineer, I want the Flutter widget smoke test to verify bootstrap and core components render so that a future regression in the design system or bootstrap surface fails loudly.

#### Acceptance Criteria

1. WHEN I run `cd apps/velix_app && flutter test` THEN the command SHALL exit 0.
2. WHEN the test "Bootstrap produces a usable result with seeded data" executes against a missing session path THEN it SHALL return a non-null identity AND an empty conversation list.
3. WHEN the smoke tests render `VelixButton`, `GlassCard`, `IdentityCapsule`, `MessageBubble` THEN every render SHALL succeed without throwing.
4. WHEN the test "chats provider streams conversations" executes THEN `conversationRepositoryProvider.watchAll().first` SHALL emit a `List<Conversation>`.

**Source of truth.** `apps/velix_app/test/widget_smoke_test.dart`, `apps/velix_app/lib/src/bootstrap/bootstrap.dart`, `apps/velix_app/lib/src/di/providers.dart`.

### Requirement 5: Server runs and serves health

**User Story:** As an alpha tester, I want to start the server with one command and confirm it is alive so that I can point a client at it.

#### Acceptance Criteria

1. WHEN I run `cd backend/alpha && go run ./cmd/alpha-server` THEN the process SHALL listen on `:8080` (or `VELIX_ADDR`).
2. WHEN I `GET /v1/healthz` THEN the server SHALL respond 200 with `{ "status": "ok", "time": ... }`.
3. WHEN I `GET /v1/readyz` THEN the server SHALL respond 200.
4. WHEN I send SIGINT THEN the server SHALL shut down gracefully within 5 seconds AND write the JSON snapshot to `VELIX_STATE_PATH` (default `velix-alpha-state.json`).
5. WHEN I restart the server with the same `VELIX_STATE_PATH` THEN the previously-registered accounts SHALL still resolve via `/v1/users/lookup`.

**Source of truth.** `backend/alpha/cmd/alpha-server/main.go`, `backend/alpha/internal/api/api.go`.

### Requirement 6: Flutter client boots end-to-end

**User Story:** As an alpha tester, I want to launch the Flutter app, register a new account, and arrive on the home screen on a fresh restart so that I can proceed to messaging.

#### Acceptance Criteria

1. WHEN I run `flutter run --dart-define=VELIX_ALPHA_URL=http://127.0.0.1:8080` against a clean device THEN the splash SHALL render AND redirect to `/auth` within 1.5 seconds.
2. WHEN I tap "Create account", enter a valid handle, and tap submit THEN the client SHALL call `POST /v1/register` AND receive a 200 AND show the account ID + device secret in a dialog.
3. WHEN I dismiss the dialog AND restart the app cold THEN the splash SHALL redirect to `/home` AND the identity stream SHALL emit my registered handle.
4. WHEN I navigate to `/chats` AND the conversation list is empty THEN the empty state SHALL render with the existing copy.

**Source of truth.** `apps/velix_app/lib/src/presentation/screens/auth/auth_screen.dart`, `apps/velix_app/lib/src/presentation/screens/splash/splash_screen.dart`, `apps/velix_app/lib/src/bootstrap/bootstrap.dart`.

### Requirement 7: Two-device messaging works

**User Story:** As an alpha tester, I want two devices to exchange a message through the running server so that the alpha is demonstrably end-to-end.

#### Acceptance Criteria

1. WHEN device A registers as `alice` AND device B registers as `bob` against the same server THEN `GET /v1/users/lookup?handle=bob` from device A SHALL return device B's account ID.
2. WHEN device A taps "+" on chats, types `bob`, AND submits THEN the client SHALL call `POST /v1/conversations` AND navigate into the chat screen.
3. WHEN device A sends a text message THEN the message SHALL appear on device A's chat list within 1 second.
4. WHEN device B opens its chats list within 5 seconds of A sending THEN the new conversation SHALL be visible.
5. WHEN device B opens the conversation within 5 seconds of A sending THEN the message body SHALL be visible.

**Source of truth.** `packages/velix_data/lib/src/alpha/alpha_api_client.dart`, `packages/velix_data/lib/src/alpha/remote_conversation_repository.dart`, `packages/velix_data/lib/src/alpha/remote_message_repository.dart`, `apps/velix_app/lib/src/presentation/screens/chats/chats_screen.dart`, `apps/velix_app/lib/src/presentation/screens/chat/chat_screen.dart`.

### Requirement 8: Persistence survives restarts

**User Story:** As an alpha tester, I want server restarts to preserve accounts and messages so that I do not have to re-register every time.

#### Acceptance Criteria

1. WHEN the server is started with a fresh state file AND I register `alice` AND I gracefully stop the server with SIGINT THEN `velix-alpha-state.json` SHALL exist on disk AND contain the account.
2. WHEN I restart the server pointing at the same state file THEN `GET /v1/users/lookup?handle=alice` SHALL return alice's account.
3. WHEN `alice` and `bob` exchanged a message before shutdown THEN after restart `GET /v1/conversations/{id}/messages` SHALL return that message.
4. WHEN the client persists `velix_alpha_session.json` THEN a cold restart of the app SHALL bypass `/auth` and route directly to `/home`.

**Source of truth.** `backend/alpha/internal/store/store.go`, `packages/velix_data/lib/src/alpha/alpha_session.dart`.

### Requirement 9: Documented validation commands

**User Story:** As a continuing engineer, I want the exact validation commands written down in one place so that running them never depends on chat history.

#### Acceptance Criteria

1. WHEN a fresh contributor reads `ALPHA.md` THEN the file SHALL list the exact commands to (a) run the backend, (b) run backend tests, (c) run dart tests, (d) run flutter analyze + test, (e) run two-device messaging.
2. WHEN the documented commands are executed in order on a developer machine with toolchains installed THEN every command SHALL succeed.

**Source of truth.** `ALPHA.md` at repo root.

### Out of scope (must remain unchanged)

- libsignal Rust FFI bodies in `cryptocore/src/{identity,session,sender_keys,sealed_sender,backup,media,livekit,ffi}.rs`. Phase 7 owns these.
- The `backend/services/...` Phase 6 service modules. Not in `go.work`. Not built.
- Voice / video / AI / stories / push notifications.
- Phase 11 launch-readiness audit work.

Any task that touches these closes immediately as out-of-scope.
