# 01 — Performance Budgets

The complete budget table. Every operation has a hard ceiling. Crossing the ceiling triggers either an automatic fix (server-side throttle, client-side fallback) or a CI failure.

## Frame budget

The single most important table.

| Surface | Reference device | Budget (p99 frame time) | Notes |
|---|---|---|---|
| Splash | any | ≤ 16.6 ms | one-shot reveal; no animation during scroll |
| Onboarding step | iPhone 12 / Pixel 6 | ≤ 16.6 ms | 3D scene runs on dedicated render isolate |
| Login / identity creation | any | ≤ 16.6 ms | crypto ops are off the UI thread |
| Home (empty) | any | ≤ 8 ms | static |
| Chat list (50 cells) | iPhone 12 / Pixel 6 | ≤ 16.6 ms | scrolling fling |
| Conversation (200 messages) | iPhone 12 / Pixel 6 | ≤ 16.6 ms | scroll + arrival animations |
| Conversation push transition | iPhone 12 / Pixel 6 | ≤ 16.6 ms | lateral motion |
| Bottom-sheet drag | iPhone 12 / Pixel 6 | ≤ 16.6 ms | gesture-driven |
| Modal arrival | iPhone 12 / Pixel 6 | ≤ 16.6 ms | spring animation |
| Story viewer transition | iPhone 12 / Pixel 6 | ≤ 16.6 ms | parallax + cross-fade |
| Voice waveform | any | ≤ 16.6 ms | 30 fps cap on repaint |
| Video call (full-bleed remote) | iPhone 12 / Pixel 6 | ≤ 16.6 ms | LiveKit handles encoding; we render |
| Profile (with 3D scene) | iPhone 12 / Pixel 6 | ≤ 16.6 ms | 3D budget ≤ 4 ms |
| Settings / privacy | any | ≤ 16.6 ms | static lists |
| AI assistant streaming | any | ≤ 16.6 ms | per-token reveal |

**Hard rule:** 99% of frames inside 16.6 ms on iPhone 12 and Pixel 6 across the journey. We measure p99 over 60-second active sessions; spikes during cold-start are excluded.

A device class below the floor (Pixel 4a, Galaxy A52) is allowed 33.3 ms (30 fps); we do not bench against this floor but we do not regress.

## Layer budgets

Within a frame, the per-layer breakdown:

| Layer | Budget (typical) | Hard ceiling |
|---|---|---|
| Build phase (widget tree diff) | ≤ 4 ms | 6 ms |
| Layout | ≤ 2 ms | 3 ms |
| Paint (CPU) | ≤ 3 ms | 5 ms |
| Compositor + raster (GPU) | ≤ 5 ms | 8 ms |
| Material 3D (Tier-3 with blur) | ≤ 2.5 ms | 4 ms |
| 3D scene (when active) | ≤ 4 ms | 5 ms |
| **Total** | **≤ 14 ms** | **16.6 ms** |

If the typical adds to 14 ms, that leaves 2.6 ms slack for tail-end events (touch tracking, heartbeats, etc.). The hard ceilings sum to more than 16.6 ms intentionally — they cannot all hit at once.

## Cold-start budget

| Phase | Budget (iPhone 12) | Budget (Pixel 6) |
|---|---|---|
| Native splash visible | ≤ 80 ms | ≤ 100 ms |
| Flutter framework boot | ≤ 250 ms | ≤ 300 ms |
| Bootstrap.run() | ≤ 200 ms | ≤ 250 ms |
| → secure storage open | ≤ 80 ms | ≤ 100 ms |
| → DB key derivation | ≤ 100 ms (one-shot per launch) | ≤ 120 ms |
| → DB open + migrations | ≤ 200 ms | ≤ 250 ms |
| → identity hydrate | ≤ 80 ms | ≤ 100 ms |
| First Home frame painted | ≤ 800 ms total | ≤ 950 ms total |
| Splash departs (motion.depart) | +220 ms (overlapped with Home arrival) | +220 ms |

**Hard target:** cold-start ≤ 800 ms on iPhone 12, ≤ 950 ms on Pixel 6, p95 over a 100-launch sample.

The "splash holds steady; never shows a spinner" rule (Phase 4 doc 06) means a slow boot is invisible to the user as long as splash is on screen — so if we miss 800 ms, we just hold splash longer. We never paint a half-built Home.

## Memory budget

Per-process at steady state:

| Tier | iPhone 12 | Pixel 6 |
|---|---|---|
| Active foreground (chat list) | ≤ 120 MB | ≤ 140 MB |
| Active conversation (open) | ≤ 180 MB | ≤ 210 MB |
| Active video call | ≤ 320 MB | ≤ 380 MB |
| Background | ≤ 60 MB | ≤ 70 MB |
| Hard ceiling (any state) | 400 MB | 500 MB |

Beyond the hard ceiling, the OS may kill the app. We must stay below.

Specific allocations:
- Drift connection pool: ≤ 4 MB resident.
- libsignal protocol-store cache: ≤ 12 MB resident.
- Image cache (decoded): ≤ 64 MB; LRU evicted.
- Filament 3D engine: ≤ 16 MB when at most one scene loaded.
- Rive runtime: ≤ 4 MB total for all glyph artboards loaded.
- AI on-device model (when loaded, single feature): ≤ 50 MB.

## Battery budget

Steady-state during typical use, on a fully-charged 2022-era phone, 50% screen brightness:

| Activity | Budget (% per hour) |
|---|---|
| Idle in chat list | ≤ 1.5 |
| Active conversation reading | ≤ 3 |
| Voice call (E2E, 1:1) | ≤ 5 |
| Video call (E2E, 1:1, 720p) | ≤ 12 |
| Background sync only | ≤ 0.4 |
| 3D backdrop active in a Space | additional ≤ 0.7 (so total ≤ ~3.5 in a Space with backdrop) |
| AI on-device session (e.g., translation in use) | additional ≤ 0.3 / minute of active inference |

These are the same numbers from Phase 1 doc 04 and Phase 3 doc 06; we re-verify here.

## Network budget

| Operation | Bytes (median) | Frequency cap |
|---|---|---|
| Outbound message envelope (text, ≤ 200 chars) | ≤ 1.5 KB | 60 / minute / account (rate limit) |
| Inbound delivery push | ≤ 2 KB | unbounded (consumer-driven) |
| Heartbeat ping | ≤ 80 bytes | every 25 s |
| Token refresh | ≤ 2 KB | every 12 minutes |
| Image upload (small image, post-encryption) | ≤ 200 KB | unbounded |
| Voice message envelope (30 s) | ≤ 80 KB | unbounded |
| 3D scene download (one scene) | ≤ 800 KB | once per scene per device |
| AI cloud query roundtrip | ≤ 16 KB | quota-bounded |

The Phase 8 OHTTP padding (256/1024/4096/16384) means small queries cost more bytes than they "should." This is privacy padding; budget accommodates it.

## Database budget

| Operation | iPhone 12 | Pixel 6 |
|---|---|---|
| DB open (cold) | ≤ 200 ms | ≤ 250 ms |
| Watch chat list (50 conversations) initial | ≤ 30 ms | ≤ 40 ms |
| Single message insert | ≤ 8 ms | ≤ 12 ms |
| Search 100k messages (FTS index) | ≤ 200 ms | ≤ 300 ms |
| Backup creation (10k messages) | ≤ 4 s | ≤ 5 s |
| Restore from backup (10k messages) | ≤ 8 s | ≤ 10 s |

These are p99 figures over 100 trials.

## Cryptographic overhead budget

(Per Phase 7 doc 04 performance targets, restated for Phase 9 verification.)

| Operation | iPhone 12 | Pixel 6 |
|---|---|---|
| Identity creation | ≤ 80 ms | ≤ 100 ms |
| X3DH session initialization | ≤ 5 ms | ≤ 8 ms |
| Encrypt message for one device | ≤ 2 ms | ≤ 3 ms |
| Decrypt one envelope | ≤ 3 ms | ≤ 4 ms |
| Sender Keys distribution (group of 50) | ≤ 50 ms | ≤ 70 ms |
| Argon2id passphrase hash | ≈ 1000 ms (calibrated) | ≈ 1200 ms |
| FFI call overhead | ≤ 50 µs | ≤ 80 µs |
| LiveKit per-frame encrypt (XChaCha20) | ≤ 0.3 ms | ≤ 0.5 ms |

If any of these regresses by >20% from baseline, it pages the team.

## AI request latency budget

| Operation | Target (median) |
|---|---|
| On-device smart-reply | ≤ 80 ms (iPhone 12) |
| On-device language detection | ≤ 5 ms |
| On-device translation (≤ 500 chars) | ≤ 200 ms |
| On-device summarization (50 messages) | ≤ 800 ms |
| On-device moderation classification | ≤ 30 ms |
| Cloud assistant first-token | ≤ 600 ms |
| Cloud assistant streaming throughput | ≥ 30 tokens/sec |
| OHTTP relay overhead | ≤ 80 ms |

## Realtime latency budget

End-to-end message delivery (sender press Send to recipient device-rendered):

| Network | Target p50 | Target p99 |
|---|---|---|
| Same region, both devices online | ≤ 120 ms | ≤ 250 ms |
| Cross-region | ≤ 280 ms | ≤ 600 ms |
| Recipient offline (push wakes device) | ≤ 4 s p95 | ≤ 12 s p99 |

## Asset / install size budget

| Item | iOS | Android |
|---|---|---|
| App install (over the wire) | ≤ 35 MB | ≤ 18 MB (split APK) |
| App on device (post-install, before content) | ≤ 80 MB | ≤ 60 MB |
| Total fonts (variable) | ≤ 1.2 MB | ≤ 1.2 MB |
| AI runtimes baseline | ≤ 8 MB | ≤ 8 MB |
| Lazy-downloaded AI models (per model) | ≤ 50 MB | ≤ 50 MB |
| Lazy-downloaded 3D scenes (per scene) | ≤ 800 KB | ≤ 800 KB |

## What happens when a budget is hit

Three responses depending on the budget class:

1. **Hard CI failure:** frame budget regression > 5%, cold-start regression > 10%, memory regression > 20%, crypto regression > 20%. Blocks merge.
2. **Soft alert:** smaller regressions log warnings on the PR; require explicit team acknowledgment.
3. **Auto-downgrade:** runtime crosses the budget on a user device → fallback (3D scene drops to 30 fps, then to 2D fallback; AI on-device model unloads if memory pressure).

## Continuous benchmarking

Every PR runs the Phase 9 doc 02 bench harness. Results stored in CI artifacts; trended on `velix.app/perf` (internal).

Nightly: full soak suite (battery, memory leak, 30-min frame stability) on dedicated bench devices.

Weekly: a deeper profile pass with platform tools (Instruments on iOS, Perfetto on Android), captured by an engineer; review meeting.

## Banned

- Local-machine "it's fast enough" judgments without bench numbers.
- Optimizations that trade off correctness, security, accessibility, or motion quality.
- Caching that violates the privacy posture (e.g., caching cloud-AI responses tied to identity).
- Performance fixes that ship without the corresponding benchmark proving they fixed something.
- Disabling the bench harness "temporarily."
- Skipping the floor device test on the assumption "premium devices are fine."
