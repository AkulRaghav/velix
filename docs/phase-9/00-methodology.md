# 00 — Performance Methodology

## Position

Performance work in Velix is **measure first, change second, verify third**. We do not optimize on intuition. We do not ship "I think this will be faster." Every optimization in Phase 9 is bound to a specific bench, with a before/after number, and a justification.

This phase produces:
- A budget table for every measurable surface (Phase 9 doc 01).
- A bench harness that runs in CI and locally (Phase 9 doc 02).
- A bottleneck catalog (Phase 9 doc 03).
- An applied-fixes log (Phase 9 doc 04).
- A residual-risks list and Phase 10 carry-forwards (Phase 9 doc 05).

The phase ships when every audited dimension has either a green number or an explicit, time-boxed follow-up.

## Pillars

1. **Profile first.** Real device, real build (release mode, profile flag enabled where instrumented). No "debug-build feels fast" claims.
2. **Bench-driven CI.** Every PR runs the bench harness on cloud devices (Pixel 6 always; iPhone 12 daily). Regressions block merge.
3. **Reference devices are immovable.** iPhone 12 (A14, 2020) and Pixel 6 (Tensor G1, 2021). We do not bench on iPhone 15 Pro and call it a day.
4. **Floor devices are tested for graceful degradation.** Pixel 4a and Galaxy A52 are bench targets for "does it still work" — not for the budgets, but for non-regression of the fallback paths.
5. **No correctness-for-speed trades.** Security, accessibility, privacy, motion quality are immovable. Performance optimizations preserve them.
6. **Each optimization is justified by a number.** A PR that says "this should be faster" is rejected. A PR that says "this reduces conversation push p99 from 18.4 ms to 14.1 ms on iPhone 12" is reviewed.
7. **Measure both phones.** A fix that helps iPhone but regresses Pixel is rolled back.

## Performance posture by layer

### Flutter rendering

The build/layout/paint/raster phases each have a budget (Phase 9 doc 01). We use:
- `RepaintBoundary` around expensive painters (waveform, 3D scene, parallax layers, story media).
- `const` constructors for every leaf widget that can be const.
- `Selector`/`select` patterns with Riverpod to scope rebuilds.
- `AutomaticKeepAlive` only where the data is genuinely expensive to recompute (chat list scroll position).
- `ListView.separated` / `ListView.builder` instead of a static `Column` of 200 messages.

Banned in Flutter:
- Building widget trees inside `build` based on async work without `FutureBuilder` / `StreamBuilder` / Riverpod.
- Calling `setState` in response to scroll events (use `ValueListenableBuilder`).
- Hidden allocations in `build` (lists, maps, closures captured) — flagged by `dart_code_metrics`.

### Motion

Phase 4 grammar is the contract. Phase 9 verifies:
- Springs run on the Flutter ticker, time-based.
- No animation during scroll (Phase 4 doc 00 ban; Phase 9 verifies).
- Reduce-Motion paths are tested via bench's MediaQuery override mode.

### Memory

We use Flutter's memory profiler nightly. We track:
- RSS at chat-list-idle.
- Heap growth over a 30-min soak.
- Allocation count per frame.

Targets in Phase 9 doc 01.

### Battery

Soak benches with Velix in foreground for 30 / 60 / 120 minutes on representative usage profiles. We measure the device's battery sensor delta (via the Battery plugin we already integrate for low-power mode detection).

### Database

Drift's `EXPLAIN QUERY PLAN` is run on every query in CI. Slow queries fail the build. The schema's index list is documented per query.

### Network

Realtime path latency is measured via synthetic probes (Phase 6 doc 10). Bench harness adds explicit latency measurements.

### Crypto

`cryptocore` has a Criterion-style bench (Rust). Numbers are tracked per-release; > 20% regression alerts.

## How we benchmark

### CI bench (every PR)

```
1. Build release-mode app for iOS and Android targets.
2. Push to BrowserStack App Live (or Sauce Labs equivalent) farm.
3. Run scripted scenarios via integration tests:
     - Cold start (10 launches, capture p95).
     - Open conversation (10 trials, capture p99 frame).
     - Send 100 messages, scroll up and down (capture p99 frame).
     - Bottom-sheet drag-to-detent (10 reps, capture p99 frame).
     - Modal arrival/dismiss (10 reps).
4. Capture timeline events (Flutter frame events + GPU timing where exposed).
5. Diff against the baseline (last green main).
6. Fail PR if any regression > thresholds.
```

### Local profiling (engineer-driven)

```
flutter run --profile -d <device>
flutter run --release -d <device>
```

Plus platform tools:
- iOS: Instruments — Time Profiler, Allocations, Energy Log.
- Android: Perfetto / Android Studio Profiler — CPU, Memory, Battery.

### Bench fixtures

The Phase 9 doc 02 bench harness ships representative fixtures:
- 4 conversations, 200 messages each.
- 2 of those conversations have 3 voice messages with envelopes.
- 1 conversation has 5 image messages.
- 1 group of 50 devices with mixed activity.
- A profile with the identity 3D scene loaded.
- A Space with the ambient backdrop.

Fixtures are seeded into the in-memory repos (Phase 5) for client-only tests, or into a docker-composed Postgres + Redis + NATS stack for full-stack tests.

## Audit dimensions

Phase 9 explicitly audits each:

| Dimension | Doc reference |
|---|---|
| Frame stability | Phase 9 doc 01 frame budget |
| Cold start | Phase 9 doc 01 cold-start budget + Phase 5 doc 00 |
| Memory leaks | Phase 9 doc 03 + nightly soak |
| Battery | Phase 9 doc 01 + soak harness |
| Database queries | Phase 9 doc 03 + drift EXPLAIN |
| Realtime path | Phase 9 doc 03 + synthetic probes |
| GPU overdraw | Phase 9 doc 03 + DevTools layer |
| Animation jank | Phase 9 doc 03 + Phase 4 motion grammar |
| 3D scene | Phase 9 doc 03 + Phase 3 perf budgets |
| Crypto overhead | Phase 9 doc 03 + cryptocore criterion |
| AI request | Phase 9 doc 03 + Phase 8 latency budgets |
| Cache hit rates | Phase 9 doc 03 |
| Background tasks | Phase 9 doc 03 |
| Push delivery | Phase 6 doc 08 + Phase 9 telemetry |
| Image / media decode | Phase 9 doc 03 |

## Banned patterns we look for

- `setState` for app-state (caught at architectural review; Phase 9 verifies via build counts).
- `ListView` (non-builder) of arbitrary content.
- `Container` chains with redundant decoration.
- `Image.network` directly (we use cached, encrypted media providers).
- `BuildContext` captured in long-lived closures.
- Synchronous file I/O on the UI thread.
- Blocking the ticker with `await` chains.

## Output of Phase 9

Each subsequent doc in this folder addresses one slice of the work:

```
docs/phase-9/
  00-methodology.md          ← this
  01-budgets.md              ← every budget, every surface
  02-bench-harness.md        ← how to run, what to capture
  03-bottleneck-catalog.md   ← suspects, mitigations
  04-fixes-applied.md        ← what we changed and why (Phase 9 work log)
  05-residual-risks.md       ← what remains; Phase 10 carry-forwards
  06-phase-9-audit.md        ← the gating audit
```

## What this phase does not do

- It does not run real device benches. The benches are specified; running them requires the device farm wired up (Phase 9.5 work, parallel to phase boundaries).
- It does not produce final numbers. Only design-time estimates with verifiable budgets.
- It does not optimize for performance at the cost of any other quality gate.
- It does not invent new optimizations. It applies known-good techniques, justifies each, and verifies via budget.
