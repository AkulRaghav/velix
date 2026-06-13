# Phase 9 — Performance Optimization

Status: in progress. Gates Phase 10.

## What ships

The complete performance methodology, budget table, bench harness specification, bottleneck catalog with mitigations, applied fixes (with code changes), residual-risks list, and the gating audit. Concrete code changes applied to the existing Phase 5 / 7 / 8 codebase.

## What does not ship

Real-device numbers. The bench harness is specified and CI-ready in design; running it on iPhone 12 / Pixel 6 cloud devices is Phase 9.5 work that requires BrowserStack App Live or Sauce Labs setup. The numbers in this phase are design-time estimates against documented budgets; verification is Phase 9.5.

This is the honest position. Performance phases on documents alone are not enough; they need device benches. Phase 9.5's first week is wiring the harness.

## Locked posture

- **Profile first.** No "I think this is faster" optimizations. Every fix bound to a budget and a bench.
- **Reference devices: iPhone 12 (A14, 2020) and Pixel 6 (Tensor G1, 2021).** Floor devices: Pixel 4a, Galaxy A52.
- **No correctness-for-speed trades.** Security, accessibility, privacy, motion quality are immovable.
- **Per-PR bench harness.** Regressions > thresholds block merge.
- **Both phones.** A fix that helps iPhone but regresses Pixel is rolled back.

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Methodology](./00-methodology.md) | Profile-first; per-layer posture; what we don't do |
| 01 | [Performance Budgets](./01-budgets.md) | Frame, cold-start, memory, battery, network, DB, crypto, AI, install size |
| 02 | [Bench Harness](./02-bench-harness.md) | Harness layout, frame timing capture, k6, Criterion |
| 03 | [Bottleneck Catalog](./03-bottleneck-catalog.md) | 24 entries: rendering, memory, cold-start, network, DB, 3D, battery, crypto, AI |
| 04 | [Fixes Applied](./04-fixes-applied.md) | F1–F14 with implementation pointers; static review of existing code |
| 05 | [Residual Risks](./05-residual-risks.md) | What's not yet measured; Phase 9.5 + 10 carry-forwards |
| 06 | [Phase 9 Audit](./06-phase-9-audit.md) | Self-review, gates Phase 10 |

## Concrete code changes in Phase 9

| File | Change | Bottleneck |
|---|---|---|
| `apps/velix_app/lib/main.dart` | Image cache bounded to 100 entries / 64 MB | F5 / B-M1 |
| `apps/velix_app/lib/src/bootstrap/bootstrap.dart` | Bootstrap parallelization via `Future.wait` | F7 / B-CS2 |
| `apps/velix_app/lib/src/presentation/screens/chats/chats_screen.dart` | `ListView.builder` + `RepaintBoundary` per cell | F1 / B-R2 |
| `apps/velix_app/lib/src/presentation/screens/chat/chat_screen.dart` | Composer state in `ValueNotifier`; message list as separate `ConsumerWidget`; per-bubble `RepaintBoundary` | F3 / F1 / B-R4 |
| `apps/velix_app/lib/src/presentation/shell/floating_nav_shell.dart` | `RepaintBoundary` per tab | F8 |
| `packages/velix_3d/lib/src/scene_widget.dart` | Visibility-fraction listener + auto-pause | F12 / B-3D1 |
| `packages/velix_motion/lib/src/realtime/typing_indicator.dart` | `RepaintBoundary` around the dot row | catalog |

## Reading order

If you have ten minutes: 00 → 04 → 06.
If you're implementing optimizations: 03 → 04 → 02.
If you're auditing: 06 → 05 → 03 → 04.
