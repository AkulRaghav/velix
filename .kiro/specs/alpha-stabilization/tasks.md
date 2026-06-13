# Implementation Plan: Alpha Stabilization & Validation

## Overview

These tasks turn the alpha into a runnable, testable build. Each task lists
the exact files it touches, the validation step that proves it works, and
the requirement it satisfies.

> **Scope guardrail.** Do not modify libsignal-bound code in `cryptocore/src/{identity,session,sender_keys,sealed_sender,backup,media,livekit,ffi}.rs`, or the Phase-6 modules under `backend/services/...`. Those belong to Phase 6/7 and are out of this spec.

## Task Dependency Graph

```
1 ──┐
    ├──> 7 ──> 8
2 ──┤
    ├──> 10 ──> 11
3 ──┤
    ├──> 5 ──> 6
4 ──┘                  ┐
                       ├──> 12 ──> 13
9 ─────────────────────┘
```

```json
{
  "waves": [
    { "wave": 1, "tasks": [1, 2, 3, 4, 9] },
    { "wave": 2, "tasks": [5, 7, 10] },
    { "wave": 3, "tasks": [6, 8, 11] },
    { "wave": 4, "tasks": [12] },
    { "wave": 5, "tasks": [13] }
  ]
}
```

## Tasks

- [x] 1. Static-trace the Go alpha module and remove unused exports / dead imports
  - Open every Go file under `backend/alpha/`. Confirm: only stdlib + `github.com/velix/backend/alpha/...` imports.
  - Confirm `store.ErrNotFound` and `store.ErrUnauthorized` are intentional public symbols (kept) or remove if dead.
  - Confirm `recordingWriter` and `withLogging` are reachable from `Handler()`.
  - Verify `handleRe` regex matches the documented bounds (3–32, `[a-zA-Z0-9._-]`).
  - _Requirements: 1.1, 1.2_

- [x] 2. Static-trace the Dart alpha client and remove unused / over-engineered code
  - Open every Dart file under `packages/velix_data/lib/src/alpha/`.
  - Confirm imports are tight (no leftover indirection).
  - Confirm `AlphaApiClient.hmacSha256`'s SHA-256 inner loop respects the precedence fixes (`(e & f) ^ ((~e & 0xffffffff) & g)`).
  - Confirm `RemoteConversationRepository.openWith` exists and returns the freshly-mapped `Conversation`.
  - _Requirements: 1.3, 1.4, 1.5, 3.1_

- [x] 3. Static-trace the Flutter app for compile-time errors
  - Re-read every screen file added or edited (`auth_screen.dart`, `splash_screen.dart`, `chats_screen.dart`, `chat_screen.dart`).
  - Confirm: every `v.colors.surface.*`, `v.colors.text.*`, `v.colors.semantic.*`, `v.type.*`, `v.space.*` accessor used actually exists in `velix_design`.
  - Confirm: every Riverpod provider referenced (`bootstrapProvider`, `chatListProvider`, `conversationProvider`, `messagesProvider`, `markAsReadProvider`, `sendMessageProvider`, `identityProvider`) resolves through `apps/velix_app/lib/src/di/providers.dart`.
  - Confirm: every `context.go(...)`, `context.push(...)`, `Routes.*` reference resolves.
  - _Requirements: 1.5, 4.1, 6.1_

- [x] 4. Verify `Bootstrap.run` is OS-portable and does not require a real session file
  - Confirm `Bootstrap.run({Uri? alphaUri, String sessionPath})` defaults to `velix_alpha_session.json` AND treats a missing file as first-run.
  - Confirm `widget_smoke_test.dart` builds the missing-session path via `Directory.systemTemp` + `Platform.pathSeparator`.
  - Add a per-OS check: on Windows the path uses `\`; on POSIX it uses `/`. If incorrect, fix in the test helper.
  - _Requirements: 4.2, 4.4, 6.3_

- [x] 5. Confirm Flutter strict-cast / strict-inference rules are not violated by alpha files
  - Walk `apps/velix_app/lib/src/presentation/screens/auth/auth_screen.dart` and the changed `chats_screen.dart`. Confirm no implicit `dynamic`, no raw `List`, no `Future<void>`-returning lambdas in a `VoidCallback` slot.
  - Fix any violation by tightening the type at the call site.
  - _Requirements: 1.5, 4.4_

- [x] 6. Document validation commands in `ALPHA.md` and verify they match `tasks.md`
  - Confirm `ALPHA.md` lists the four canonical command blocks (server, backend tests, dart tests, flutter analyze + test, manual two-device).
  - Confirm the values of `--dart-define=VELIX_ALPHA_URL=...` match `Bootstrap.defaultAlphaUri()` per platform.
  - Update `ALPHA.md` if any drift is found.
  - _Requirements: 9.1, 9.2_

- [x] 7. Confirm the in-memory `Store` JSON shape round-trips
  - Re-read `backend/alpha/internal/store/store.go`.
  - Confirm `Snapshot` is exhaustive and matches the design's "Database model" (accounts, handles, sessions, conversations, messages, challenges).
  - Confirm `Save` writes via `<path>.tmp` then `Rename`. Confirm `Load` returns nil on `os.ErrNotExist`.
  - Verify `TestSnapshotPersistence` covers an account round-trip; if it does not assert conversation/messages persistence, add the assertion.
  - _Requirements: 8.1, 8.2, 8.3_

- [x] 8. Confirm idempotent conversation upsert and the "open conversation" flow
  - Inspect `store.UpsertConversationFor`. Confirm: opening with `(A,B)` then `(B,A)` returns the same conversation row.
  - Add a Go test `TestOpenConversation_IsIdempotent` that registers two accounts, opens the conversation twice (`(A→B)` and `(B→A)`), and asserts the same id.
  - _Requirements: 7.1, 7.2_

- [x] 9. Confirm the `+` button and lookup flow on the chats screen
  - Trace the `_newConversation` flow in `chats_screen.dart`.
  - Confirm: when the user types a peer handle, the client calls `lookup` then `openWith`, then navigates to `/chats/{id}`.
  - Confirm: when the user is in in-memory mode (no session), the snackbar fallback fires.
  - _Requirements: 7.2_

- [x] 10. Confirm the polling flow stops when watchers detach
  - Trace `RemoteConversationRepository.watchAll`'s `controller.onCancel` and ref-count decrement.
  - Confirm: the timer cancels when the last watcher leaves.
  - Same for `RemoteMessageRepository._Channel.attach`.
  - Add a Dart test (against a fake `AlphaApiClient`) that asserts: subscribe → unsubscribe → no further polls happen.
  - _Requirements: 7.4, 7.5_

- [x] 11. Confirm error paths on the API client
  - `AlphaApiException` is thrown for non-2xx responses, with `statusCode` + decoded `error` field.
  - Add a small Dart unit test that uses an `HttpClient` fake to return 401 / 409 / 500 and asserts the exception body.
  - _Requirements: 1.4_

- [x] 12. Self-validate the spec against repo state
  - Diff this `tasks.md` against the actual files under `backend/alpha/`, `packages/velix_data/lib/src/alpha/`, and `apps/velix_app/lib/src/presentation/screens/auth/`.
  - For every "Source of truth" path mentioned in the design and requirements, confirm the file exists.
  - Patch design or requirements where the doc lags reality.
  - _Requirements: 9.1, 9.2_

- [ ] 13. Final manual smoke-run on a developer machine (handed to the human)
  - Run, in order: `go test ./...`, `dart test`, `flutter analyze`, `flutter test`, `go run ./cmd/alpha-server`, `flutter run --dart-define=VELIX_ALPHA_URL=...`.
  - Register two accounts on two devices.
  - Send a message both directions.
  - Stop the server with SIGINT, restart, confirm the message persists.
  - _Requirements: 5, 6, 7, 8_

## Notes

- Tasks 1–6 are static-trace passes; they do not need a running toolchain.
- Tasks 7–11 may add small tests; they require the toolchains to actually run, but the test code itself is written without running it.
- Tasks 12–13 are validation; they happen on the developer machine, not in the agent's environment.
- If any task surfaces a real defect (missing field, broken import, wrong type), fix it in place and update the design / requirements only if reality has drifted from what the spec claims.
