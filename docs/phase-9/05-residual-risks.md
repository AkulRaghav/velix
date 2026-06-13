# 05 — Residual Risks & Phase 10 Carry-forwards

What we know is not optimized yet, what we suspect is not optimized, and what we deliberately accept as cost. Phase 10 (DevOps & Production) inherits these as its first-week tasks.

## Residual risks

### R1 — No real-device numbers yet

**Risk:** The bench harness specification (Phase 9 doc 02) and budgets (doc 01) are concrete, but no PR has run them on iPhone 12 / Pixel 6 because the device farm wiring is Phase 9.5 work. The numbers in `04-fixes-applied.md` are estimates based on the Flutter framework's published costs, libsignal's published benchmarks, and our static analysis.

**Impact:** A genuine performance regression could ship without being caught.

**Mitigation:** Phase 9.5 wires BrowserStack App Live + Sauce Labs into CI before any public-1.0 release candidate. Phase 9 commits to the harness; Phase 9.5 runs it.

**Status:** Tracked.

### R2 — FTS5 search not implemented

**Risk:** Local message search is currently a linear scan of the messages table. At 100k messages, the scan takes > 500 ms.

**Impact:** Search feels sluggish for power users.

**Mitigation:** Phase 9.5 — drift's FTS5 virtual-table extension; trigger-maintained index.

**Status:** Tracked.

### R3 — libsignal cache config

**Risk:** When the Phase 7 implementation lands, the libsignal protocol-store's session cache will need explicit bounds or memory grows linearly with session count.

**Impact:** Power users with hundreds of sessions could see > 10 MB resident in libsignal alone.

**Mitigation:** Phase 7.5 — implement the protocol-store traits with LRU bounds and memory-pressure eviction.

**Status:** Tracked.

### R4 — Cryptocore Criterion benches not run

**Risk:** Phase 9 doc 02 specifies Criterion benches for the cryptographic core; they are not run because the core isn't implemented.

**Impact:** Cryptographic regressions could ship without being caught.

**Mitigation:** Phase 7.5 — implement the core; Phase 9.5 — wire Criterion into CI.

**Status:** Tracked.

### R5 — Dart heap residue for plaintext

**Risk:** Phase 7 doc 18 H acknowledged that Dart's GC cannot guarantee zero-on-drop for plaintext strings. A forensic adversary with a memory dump could recover recent message text from the Dart heap.

**Impact:** Bounded forensic exposure window for plaintext (until next GC sweep, typically seconds).

**Mitigation:** Hardware-backed keys mean the DB itself cannot be unlocked without the device. The window of exposure is the rendered frame; we minimize that. Full mitigation would require Rust-managed plaintext for the entire UI pipeline, which is not realistic.

**Status:** Acceptable as documented.

### R6 — Traffic analysis

**Risk:** Phase 7 doc 18 D acknowledged that the routing service sees recipient + size + timing of envelopes. Velix's 256-byte padding buckets reduce but do not eliminate fingerprinting.

**Impact:** A passive observer with full traffic capture can correlate user activity patterns to some degree.

**Mitigation:** Mixnet / cover traffic prototype is post-1.0 (Phase 7 doc 01 N1).

**Status:** Acceptable as documented.

### R7 — Battery soak depends on real-device run

**Risk:** Battery budget targets in Phase 9 doc 01 (≤ 4% / hour active foreground use) are not yet measured.

**Impact:** A regression in the realtime path or 3D pipeline could blow the battery budget without a CI failure.

**Mitigation:** Phase 9.5 wires nightly battery soak on dedicated bench devices.

**Status:** Tracked.

### R8 — `BackdropFilter` cost on Android < 12

**Risk:** Older Android versions do not have `RenderEffect`; backdrop blur is implemented via offscreen layers which are slower.

**Impact:** Floor devices (Pixel 4a, Galaxy A52) show a noticeable frame drop when scrolling under a Tier-3 surface.

**Mitigation:** B-R1 mitigation #3 — cache the blur and re-blur only on scroll-end. Tier-3 surfaces (modals) are already rare during scroll.

**Status:** Mitigated by design; Phase 9.5 verifies on the floor device.

### R9 — Cryptocore Argon2id parameters on floor devices

**Risk:** Argon2id with default 64 MiB memory may exceed available RAM on a floor device with 2 GB total.

**Impact:** Backup creation OOM-kills on Pixel 4a in low-memory scenarios.

**Mitigation:** Calibration at first backup (Phase 7 doc 11) measures actual time; result cached. We do not auto-reduce memory; that would weaken the cryptographic property. We do verify that Argon2id at our params does not OOM on the floor device.

**Status:** Tracked for Phase 9.5 verification.

### R10 — drift WAL checkpointing under heavy write

**Risk:** During heavy receive (a backlog drain after long offline), the WAL grows; checkpointing is async; memory grows briefly.

**Impact:** Brief memory spike (~30-50 MB transient) on receiving a large offline backlog.

**Mitigation:** Configure SQLCipher's `journal_size_limit` to 16 MB; aggressive `wal_autocheckpoint`. Drain operations chunked at 100 messages with explicit checkpoints.

**Status:** Applied at the Phase 5 doc 04 schema spec; verified by Phase 9.5 soak.

### R11 — AI on-device model memory

**Risk:** Each loaded AI model adds ~50 MB resident; with all features enabled, ~150 MB.

**Impact:** On a 2 GB-RAM device, 150 MB is significant; may trigger OS pressure.

**Mitigation:** LRU-evict AI models from memory when not in active use. Reload on next invocation (~80 ms one-time cost).

**Status:** Tracked for Phase 8.5 (the AI model lifecycle is Phase 8.5 work).

### R12 — Push delivery latency on Android

**Risk:** FCM has SLA latencies up to several seconds in rare cases. We cannot improve FCM.

**Impact:** Users on Android may see "doorbell" delays for offline messages.

**Mitigation:** None at our layer; the `routing.Subscribe` stream re-establishes immediately on app foreground and drains the offline queue from Postgres regardless of push delivery.

**Status:** Acceptable as documented (Phase 6 doc 08 push posture).

## Phase 10 carry-forwards

The "what comes next" list. Phase 10 is DevOps & Production; Phase 9.5 is the immediate post-Phase-9 perf work.

### Immediate (Phase 9.5)

| Item | Why |
|---|---|
| Wire BrowserStack App Live + Sauce Labs into CI | Run the harness on real devices |
| Implement FTS5 search via drift extension | R2 |
| Run Criterion benches against cryptocore | R4 |
| Battery soak nightly | R7 |
| Test Argon2id on Pixel 4a / Galaxy A52 | R9 |
| Configure libsignal cache bounds | R3 |
| Measure scrolling under Tier-3 modals on Pixel 4a | R8 |
| AI model LRU eviction implementation | R11 |
| First end-to-end performance regression baseline | All |

### Phase 10 (DevOps & Production)

| Item | Why |
|---|---|
| Per-region cell deployment | Phase 1 doc 06 / 08 |
| Postgres replication + failover playbook | Phase 6 doc 11 |
| NATS JetStream cluster topology | Phase 6 doc 06 |
| Redis cluster sizing per stage | Phase 6 doc 05 |
| LiveKit cluster autoscaling | Phase 6 doc 07 |
| OHTTP relay operator contract finalized | Phase 8 doc 05 |
| Provider contracts (Anthropic, OpenAI) | Phase 8 doc 15 |
| First independent security audit (cryptocore) | Phase 7 doc 18 |
| First independent privacy audit (AI gateway) | Phase 8 doc 16 |
| App Store / Play Store submission | Phase 10 |
| Public security paper | Phase 10 |

### Permanent backlog (annual review)

| Item | Why |
|---|---|
| Post-quantum hybrid (X25519 + ML-KEM-768) | When libsignal upstream lands it |
| MLS evaluation for v2 | When MLS implementations mature |
| Mixnet / cover traffic prototype | Mitigates R6 |
| Vision Pro spatial client | Quarter +2 per Phase 1 doc 04 |
| ActivityPub bridging for public surfaces | Quarter +2 |

## What "done" looks like for Phase 9.5

- The bench harness runs on every PR; results comment on the PR; regressions block merge.
- Cold-start ≤ 800 ms verified on iPhone 12 and ≤ 950 ms on Pixel 6 across 100 launches.
- All frame-stability budgets (Phase 9 doc 01) verified green for 10 consecutive bench runs.
- Battery soak verified green for 30-min and 60-min profiles.
- Memory leak hunt (30-min cycle bench) shows ≤ 10% growth.
- All 24 cataloged bottlenecks (Phase 9 doc 03) have a concrete bench result, not just a fix description.

Until then, Phase 9 is approved with these residual risks documented.
