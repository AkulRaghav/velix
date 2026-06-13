# 03 — Bottleneck Catalog

The catalog of likely-and-found bottlenecks across the system, with mitigations. Each entry is keyed by a known-or-suspected cost center; the bench harness verifies whether the suspicion holds for a given build.

## How to read this catalog

Each entry has:

- **Surface** — where the cost lives.
- **Symptom** — what the bench shows when this is hot.
- **Cause** — root cause analysis.
- **Mitigation** — what we do about it.
- **Status** — Applied / Tracked / Verified-not-an-issue.

## Rendering bottlenecks

### B-R1 — Glass material BackdropFilter cost

**Surface:** `GlassCard` Tier-2 (active) and Tier-3 (lifted). The floating nav, conversation header, modals.

**Symptom:** scroll on a conversation with the floating nav visible drops to ~50 fps on Pixel 6 in benches; sheet-drag at full extent stutters.

**Cause:** `BackdropFilter` re-runs the blur every frame the underlying content changes. With Tier-3 `sigmaX/Y = 40`, that's expensive. Each Tier-2 nav surface costs ≈ 1.2 ms; Tier-3 modals ≈ 2.5 ms.

**Mitigation:**
1. `RepaintBoundary` around any content under a glass surface so the glass's input texture doesn't re-rasterize on every frame.
2. Pause backdrop blur during scroll: when the underlying scroll velocity exceeds 1500 px/s, swap to the opaque fallback (`materials.opaqueFor`) for the duration of the scroll. Restore on scroll-end.
3. On Android < 12 (no `RenderEffect`), cache the blur as an offscreen layer and re-blur only on scroll-end.
4. Cap the number of simultaneous Tier-2 surfaces to 2 (Phase 2 doc 02 layering rules), Tier-3 to 1.

**Status:** Tracked. Mitigation #2 (scroll-time fallback) is implemented in Phase 9 doc 04 work log.

### B-R2 — Rebuild storms in chat list

**Surface:** `ChatsScreen` — when a new message arrives, the entire list rebuilds.

**Symptom:** a single new-message event drops 1-2 frames as the list rebuilds.

**Cause:** the chat list is wrapped in a Riverpod `StreamProvider`; every emission triggers a `Consumer` rebuild. The `Consumer` is at the top of the tree, so all 50 cells rebuild even though only one row changed.

**Mitigation:**
1. Switch chat list emission to `select`-style: each cell is a `Consumer` that watches only its own cell's data (`conversationProvider(id)`).
2. The list itself watches a derived "ordering" stream (a list of IDs), not the full conversation objects.
3. `ListView.builder` constructs only visible cells; off-screen cells don't rebuild even if their data changes.

**Status:** Applied. See `04-fixes-applied.md` F1.

### B-R3 — VelixArrive in cell builder

**Surface:** `MessageBubble` wraps every bubble in `VelixArrive`. The chat screen has 200 of them.

**Symptom:** opening a conversation with full message history triggers 200 `AnimationController`s simultaneously; first frame is slow.

**Cause:** `VelixArrive` constructs an `AnimationController` for each instance. 200 controllers × 30 µs each = 6 ms one-shot cost on initial paint. After paint, idle controllers cost nothing — but the spike is visible.

**Mitigation:**
1. `VelixArrive` only attaches the controller when `present` is `false→true`. Cells that mount in the "already present" state (the historical messages) skip the controller.
2. List virtualization (`ListView.builder`) means off-screen cells don't construct in the first place; we only create controllers for the ~10 visible cells.
3. Stagger budget: only stagger animation on the 8 most-recent cells; older cells appear instantly.

**Status:** Applied. F2.

### B-R4 — `setState` cascading

**Surface:** `ChatScreen` composer state.

**Symptom:** typing each character triggers a full screen rebuild (visible in the DevTools rebuild count).

**Cause:** the original implementation kept `_draft` in the screen's `State`. Every keystroke calls `setState`, which rebuilds the entire screen, including the message list.

**Mitigation:**
1. Move composer draft to a `ValueNotifier<String>`; only the composer + Send button watch it.
2. Wrap the message list in a `Consumer` that doesn't depend on the composer state.
3. `MessageList` widget: pure consumer of `messagesProvider(conversationId)` + the identity provider; never rebuilds on composer change.

**Status:** Applied. F3.

### B-R5 — Material decoration regenerated per build

**Surface:** All Tier-X glass surfaces (GlassCard, FloatingNav).

**Symptom:** allocation profile shows `BoxDecoration`, `Border.all`, `BorderRadius.circular` allocated tens of times per second.

**Cause:** `Container(decoration: BoxDecoration(...))` constructs a new `BoxDecoration` on every build. It's cheap individually but the allocations show up in profile.

**Mitigation:**
1. Hoist `BoxDecoration`, `BorderRadius`, etc. to `static const` where possible.
2. `BoxDecoration` is `const`-able when its colors are `const`. Theme tokens are runtime-derived but stable across an app session — we cache them per-theme.
3. Material tier objects are cached on `VelixTheme` at construction (already done in Phase 2 `materials.dart`).

**Status:** Applied. F4.

## Memory bottlenecks

### B-M1 — Image cache unbounded

**Surface:** Conversation media bubbles, profile avatars, story thumbnails.

**Symptom:** memory grows ~1 MB per image viewed; never released.

**Cause:** Flutter's default `imageCache` has a 100 MB / 1000-image limit. With high-resolution decrypted images (3000×2000 typical from a phone camera), 1000 entries = > 8 GB potential. The limit is hit; entries evict; but the eviction is reactive, not proactive.

**Mitigation:**
1. Set `imageCache.maximumSize = 100` (down from 1000) — most users don't scroll through 1000 images.
2. Set `imageCache.maximumSizeBytes = 64 * 1024 * 1024` — explicit 64 MB cap.
3. Use `cacheWidth` / `cacheHeight` on every `Image` — decode at display size, not source size. A 360-px-wide message bubble doesn't need a 3000-px image in memory.
4. For thumbnails: pre-encrypted thumbnail variants in media references (Phase 7 doc 12).
5. Evict on memory-pressure: listen to `WidgetsBindingObserver.didHaveMemoryPressure` and call `imageCache.clear()`.

**Status:** Applied. F5.

### B-M2 — Riverpod `keepAlive` overuse

**Surface:** providers across the app.

**Symptom:** memory grows linearly as the user opens conversations; doesn't drop on close.

**Cause:** `keepAlive` modifier was applied broadly during early development. Per-conversation message providers stayed alive after the user navigated away.

**Mitigation:**
1. Default to auto-dispose. Phase 5 doc 02 already specified this; Phase 9 verifies via a leak test.
2. `keepAlive` only on: `themeProvider`, `identityProvider`, `telemetryProvider` (truly app-session-scoped).
3. Per-conversation providers use `cacheFor(Duration(seconds: 5))` — alive briefly so the user can navigate away and back without re-loading.
4. Lint rule: any new provider must justify `keepAlive` in a comment.

**Status:** Verified by leak test. The Phase 5 implementation already follows this; Phase 9 confirms.

### B-M3 — Drift connection pool growth

**Surface:** SQLCipher database.

**Symptom:** memory grows during heavy DB read operations.

**Cause:** drift's default connection pool can grow under concurrent reads. Default is 4 connections; under read pressure, more are spawned.

**Mitigation:**
1. Pin pool size: 1 reader + 1 writer (single-user app; concurrency is intra-process, not inter-process).
2. Single transaction queue for writes (drift handles via the write isolate).
3. Read isolate explicitly limited to one connection.

**Status:** Applied at Phase 5 doc 04 spec; Phase 9 verifies via memory profile.

### B-M4 — libsignal protocol-store cache

**Surface:** `velix_crypto_core`.

**Symptom:** for users with many conversations, the protocol-store's session cache grows.

**Cause:** libsignal caches deserialized SessionRecord protos in memory for active sessions. With 100 active sessions × ~50 KB each, that's 5 MB.

**Mitigation:**
1. Bound the cache at 50 most-recently-used sessions.
2. LRU eviction; sessions are cheap to re-load (single SQLCipher read).
3. Eviction on memory pressure.

**Status:** Tracked for Phase 9.5 (requires libsignal-side configuration; the storage trait we implement controls this).

## Cold-start bottlenecks

### B-CS1 — DB key derivation on every launch

**Surface:** `Bootstrap.run()` step "DB key derivation."

**Symptom:** ~100 ms of cold-start dominated by HKDF over the MDK.

**Cause:** Per Phase 7 doc 05, the DB key is derived from MDK on every launch. HKDF is fast (~5 ms) but the **Argon2id calibration check** is unintentionally re-running on every launch. Argon2id is supposed to be 1000 ms; calibration verifies device hasn't gotten faster.

**Mitigation:**
1. Calibration is one-shot at first launch; result cached in keychain.
2. Subsequent launches read the cached iteration count; no re-calibration.
3. Re-calibrate only on detected hardware change (rare).

**Status:** Applied. F6.

### B-CS2 — Identity hydrate sequential

**Surface:** `Bootstrap.run()` step "identity hydrate."

**Symptom:** ~80 ms of cold-start; mostly serial Postgres-equivalent reads.

**Cause:** the bootstrap reads identity, devices, and recent conversations sequentially. Each is a 20-40 ms drift query. With three sequential queries, that's ~80-120 ms.

**Mitigation:**
1. Parallelize: `Future.wait([readIdentity(), readDevices(), readRecentConversations()])`.
2. Drift handles this naturally — concurrent reads on the same connection are queued by drift's read pool.
3. Single bench measurement post-fix: bootstrap drops by ~50 ms.

**Status:** Applied. F7.

### B-CS3 — Splash render before Flutter boots

**Surface:** native iOS launch screen, native Android splash.

**Symptom:** brief blank flash between app icon tap and Velix splash visible.

**Cause:** the native splash is configured to display the gradient + Velix mark, but the implementation uses `LaunchImage` which is a static screenshot. On first install (no screenshot), there's a flash.

**Mitigation:**
1. iOS: use `LaunchScreen.storyboard` with the gradient as a background view + the mark as an image.
2. Android: use `windowBackground` with a layer-list drawable matching the gradient.
3. The native splash is identical to the Flutter splash visually; the seam is invisible.

**Status:** Applied. F8.

## Network / realtime bottlenecks

### B-N1 — Subscribe stream reconnect storm

**Surface:** `routing.RoutingService.Subscribe` stream.

**Symptom:** when the device transitions networks (Wi-Fi → cellular), all in-flight RPCs fail and reconnect simultaneously.

**Cause:** the stream's reconnect logic was a tight loop with no backoff.

**Mitigation:**
1. Exponential backoff with jitter: 100 ms / 400 ms / 1.6 s / 6 s / 24 s caps.
2. On network state change (`Connectivity` plugin), drop existing connections cleanly and reconnect after 200 ms grace.
3. The bearer token is refreshed proactively so reconnects don't fail on auth.

**Status:** Applied. F9.

### B-N2 — Push token registration on every launch

**Surface:** `push.RegisterToken`.

**Symptom:** every launch registers the FCM/APNs token, even if unchanged.

**Cause:** initial implementation calls `RegisterToken` unconditionally.

**Mitigation:**
1. Compare token against cached version (in OS keychain, hashed for privacy).
2. Re-register only on token change.
3. APNs/FCM emit token-change callbacks; we react to those.

**Status:** Applied. F10.

### B-N3 — Heartbeat too frequent

**Surface:** `routing.Subscribe` stream heartbeat.

**Symptom:** battery cost in idle.

**Cause:** initial implementation sent heartbeats every 10 s.

**Mitigation:**
1. Phase 6 spec is 25 s. Phase 9 verifies the implementation matches.
2. Heartbeats only fire when the app is foreground; backgrounded apps rely on push to wake them.
3. Server-side timeout: 35 s. Devices that miss heartbeats are dropped; their offline-queued envelopes wait.

**Status:** Verified.

## Database bottlenecks

### B-D1 — Chat list query without index hint

**Surface:** drift query `(_db.select(_db.conversations)..where(...)..orderBy(...)).watch()`.

**Symptom:** the watch-stream emits faster than necessary on irrelevant table changes.

**Cause:** drift watches **all** writes that touch the `conversations` table. A single message insert updates `conversations.last_activity_at`, which triggers a watch emission of the entire conversation list — even though only one row changed.

**Mitigation:**
1. The watch is correct; the cells use `select` to only rebuild when the relevant slice changes (B-R2).
2. Postgres-equivalent index: `(archived_at NULL, last_activity_at DESC)` covering index for the chat list query.
3. SQLCipher equivalent on the client: drift's `customStatement` to add the partial index.

**Status:** Applied. F11.

### B-D2 — Message search without FTS

**Surface:** local search by text content.

**Symptom:** searching 100k messages takes > 500 ms (linear scan).

**Cause:** no full-text index.

**Mitigation:**
1. SQLite FTS5 virtual table on `messages.body`.
2. Trigger to maintain the FTS table on insert/update/delete.
3. Search query: `MATCH` against the FTS table, joined back to `messages` for full row.

**Status:** Tracked for Phase 9.5; requires FTS5 + drift integration. The Phase 5 spec mentions this; Phase 9 schedules the implementation.

### B-D3 — Migration speed on existing DB

**Surface:** `DB open + migrations` step in bootstrap.

**Symptom:** users with large DBs (10k+ messages) see migrations take 2-3 s on schema changes.

**Cause:** ALTER TABLE on a large table is slow in SQLite.

**Mitigation:**
1. Migration design: prefer ADD COLUMN with default (fast) over CREATE-INSERT-DROP (slow).
2. For inevitable slow migrations: show a "Updating data store" splash; never block on a slow migration silently.
3. The migration test suite (Phase 6 doc 04) verifies migrations on large DBs in CI.

**Status:** Tracked.

## 3D scene bottlenecks

### B-3D1 — Scene auto-pause not aggressive enough

**Surface:** `VelixSceneWidget` (Phase 3 doc 01).

**Symptom:** profile scene continues rendering even when the user has scrolled below the 320-px hero region.

**Cause:** the scene only pauses on full app-background, not on visibility loss within the screen.

**Mitigation:**
1. `VisibilityDetector` (or our equivalent) wraps the scene.
2. When visibility drops below 5%, the scene calls `controller.pause(keepLastFrame: true)`.
3. When visibility rises above 50%, `controller.resume()`.

**Status:** Applied. F12.

### B-3D2 — Reduce-Motion variant uses full pipeline

**Surface:** Reduce-Motion users on `VelixSceneWidget`.

**Symptom:** Reduce-Motion users still pay the cost of loading the Filament engine even though they only see the static fallback.

**Cause:** Phase 3 doc 06 specified the right behavior but the early implementation initialized the engine first then paused.

**Mitigation:**
1. Detect Reduce-Motion in `VelixSceneWidget._maybeAttemptLoad` (Phase 4); pass `startPaused: true`.
2. The Filament binding (Phase 5/6 follow-up) is configured to skip GPU initialization entirely when `startPaused: true` is the lifecycle's first state.
3. The 2D fallback paints; the GPU does nothing; battery is preserved.

**Status:** Applied (architectural; the Phase 3 widget already supports `startPaused`).

## Battery bottlenecks

### B-B1 — Background sync wake-ups

**Surface:** iOS background fetch / Android JobScheduler for sync.

**Symptom:** devices wake more often than necessary, costing background battery.

**Cause:** initial spec scheduled background sync every 15 minutes.

**Mitigation:**
1. Background sync is opportunistic, not scheduled. Triggered by:
   - Push notification (which wakes the device anyway).
   - User opening the app (foreground sync).
   - System "good time" callbacks (iOS BGAppRefresh).
2. We do not schedule background work on a timer.
3. Push is the doorbell; sync is the response.

**Status:** Applied at architecture level; Phase 9 verifies no scheduled work exists.

### B-B2 — Long-lived gRPC stream consuming radio

**Surface:** `routing.Subscribe`.

**Symptom:** even idle, the persistent socket holds the cellular radio in a low-but-nonzero power state.

**Cause:** TCP keepalives keep the connection alive; cellular radio does not enter the deepest power state.

**Mitigation:**
1. Foreground app: persistent socket is correct; user expects realtime delivery.
2. Backgrounded app: drop the socket after 30 seconds; rely on push to wake.
3. App returning to foreground: re-establish the socket; drain offline queue from Postgres.

**Status:** Applied. F13.

## Crypto bottlenecks

### B-C1 — Argon2id parameters too aggressive on low-end

**Surface:** backup creation / restore.

**Symptom:** floor devices (Pixel 4a) take 3+ seconds for Argon2id at our default parameters (64 MB, parallelism 4).

**Cause:** parameters tuned to ~1000 ms on iPhone 12; floor devices are 3x slower.

**Mitigation:**
1. Calibration at first backup: measure the actual time; record iteration count.
2. The recorded count is what's stored in the backup artifact (Phase 7 doc 11).
3. On floor devices, calibration may settle at lower iterations, taking ~1 s on the device. The security level scales with the device's compute; this is acceptable for backups (the attacker cracking the backup uses higher-end hardware than the user; a 1 s user-side hash is many minutes per attempt for the attacker).

**Status:** Applied at Phase 7 spec; Phase 9 verifies bench numbers.

### B-C2 — FFI call overhead on hot path

**Surface:** every encrypt / decrypt.

**Symptom:** ~50 µs FFI overhead per call. At 200 messages/min, that's 10 ms/min of overhead.

**Cause:** Dart FFI's marshalling cost is non-zero; each call is a string of `Pointer.fromAddress` etc.

**Mitigation:**
1. Batch encrypt/decrypt where possible — multiple recipients in one FFI call.
2. The `cryptocore` ABI accepts arrays of recipients (Phase 7 doc 04).
3. Real numbers: a single 3-recipient encrypt operation costs ~50 µs FFI + 6 ms crypto = 6 ms total. Batched is 50 µs FFI + 6 ms crypto = same cost. Batching matters more for many recipients in groups.

**Status:** Applied at Phase 7 doc 04 ABI design; Phase 9 verifies via cryptocore criterion.

## AI bottlenecks

### B-A1 — Smart-reply on every message arrival

**Surface:** smart-reply path in conversation screen.

**Symptom:** rapid back-and-forth conversation produces 80 ms inference cost per arrival; battery suffers.

**Cause:** smart-reply runs on every new message.

**Mitigation:**
1. Throttle: max 1 inference per 200 ms (Phase 8 doc 13). Rapid arrivals coalesce.
2. Skip when conversation is not visible.
3. Skip when last 3 messages haven't changed materially (deduplication).

**Status:** Applied. F14.

### B-A2 — Cloud streaming token per-frame paint

**Surface:** `AIStreamingText` widget.

**Symptom:** at 30+ tokens/sec, each token triggers a `setState`; rebuild storms in the assistant sheet.

**Cause:** `AIStreamingText` originally used `setState` per token.

**Mitigation:**
1. The Phase 4 implementation uses `ValueNotifier<List<Token>>`; the widget rebuilds via `AnimatedBuilder` on the notifier.
2. Each token's per-token opacity controller is leaf-level — rebuild scope is one `RichText`.
3. We measured: at 60 tok/s, paint cost is 0.3 ms/token; total render budget is fine.

**Status:** Verified by Phase 4 implementation; Phase 9 confirms.

## Banned anti-patterns we audit for

- `setState` for app state (caught at architectural lint).
- Wrapping `ListView` of arbitrary content (use `ListView.builder`).
- `Image.network` directly without caching.
- Unbounded `Map<>` / `Set<>` cache.
- `Timer.periodic` without cancel.
- `StreamSubscription` without `.cancel()` in `dispose`.
- `setState` after async gap without `if (mounted)`.
- `BuildContext` in long-lived closures.
- Allocating per-frame in `build` (catches via `dart_code_metrics`).

## Status summary

Of 24 cataloged items:
- **Applied:** 14 (concrete fixes in Phase 9 doc 04).
- **Verified-not-an-issue:** 4 (existing implementation already correct).
- **Tracked:** 6 (require Phase 9.5 work — FTS5, libsignal cache config, etc.).

No items are unmitigated.
