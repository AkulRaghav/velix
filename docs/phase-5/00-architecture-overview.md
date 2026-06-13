# 00 — Architecture Overview

The Velix Flutter application implements **clean architecture** with strict layer boundaries, **Riverpod 2.x** for state and dependency injection, **go_router** for routing, and **drift over SQLCipher** for offline-first persistence. Every visible surface composes the three Phase 2–4 packages (`velix_design`, `velix_3d`, `velix_motion`).

## Top-level shape

```
apps/velix_app/                       ← the Flutter binary
  lib/
    main.dart                         ← bootstrap (single entrypoint)
    src/
      app.dart                        ← MaterialApp + router
      router/                         ← go_router config + typed routes
      di/                             ← Riverpod providers + scopes
      observers/                      ← analytics, error, performance
      presentation/
        screens/                      ← all 15 Phase-2 screens
        components/                   ← Velix component library impls
        floating_nav.dart             ← bottom navigation
      bootstrap/                      ← BootstrapResult, BootstrapPhase
  test/
  integration_test/

packages/                             ← internal Dart packages
  velix_design/                       ← Phase 2 (tokens, theme)
  velix_3d/                           ← Phase 3 (3D contracts)
  velix_motion/                       ← Phase 4 (motion grammar)
  velix_domain/                       ← entities, value objects, use cases
  velix_data/                         ← repositories, drift database, secure storage
  velix_crypto/                       ← libsignal Dart FFI surface (stubs in P5)
  velix_telemetry/                    ← OTel SDK wrapper, breadcrumbs, perf timeline
```

The **`apps/velix_app`** package is a thin shell — its job is to compose. All meaningful logic lives in feature packages.

## Layered architecture

Strict three-layer separation. Imports flow only inward.

```
presentation  ─────► domain ◄───── data
   (screens,           (entities,         (drift db,
    components,         use cases,         repositories,
    Riverpod            repository          gateways,
    notifiers)          interfaces)         secure storage)
```

Rules:
1. `presentation` may import from `domain` only. Never from `data` directly.
2. `domain` imports from neither `presentation` nor `data`. It is pure Dart with no Flutter dependency. Velix domain code can be tested headless.
3. `data` may import from `domain` (it implements the interfaces). It may not import from `presentation`.
4. Cross-feature imports are forbidden inside `domain` — features compose at the `presentation` layer or via shared domain primitives.

CI enforces these rules with a custom lint (`tools/import_lint.dart`).

## Module boundaries

`velix_domain` is the contract surface. The other layer-packages depend on it; it depends on none of them. This is the **dependency inversion principle** applied at package granularity.

| Package | Depends on |
|---|---|
| `velix_design` | flutter |
| `velix_motion` | `velix_design` |
| `velix_3d` | `velix_design` |
| `velix_domain` | (none — pure Dart) |
| `velix_crypto` | `velix_domain` |
| `velix_data` | `velix_domain`, `velix_crypto` |
| `velix_telemetry` | (none beyond OTel) |
| `velix_app` | all of the above |

## Bootstrap sequence

`main.dart` runs the bootstrap inside a guarded zone with telemetry instrumentation. The bootstrap orchestrates secure-storage open, database open (with SQLCipher key derivation), identity load, and root provider scope creation, in a defined order.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runZonedGuarded(() async {
    final boot = await Bootstrap.run();
    runApp(VelixApp(bootstrap: boot));
  }, _onUncaughtError);
}
```

Phases of bootstrap:

| Phase | Time budget |
|---|---|
| Native splash visible | until Flutter first frame |
| `Bootstrap.run()` | ≤ 600 ms total |
| ↳ secure storage open | ≤ 80 ms |
| ↳ DB key derivation | ≤ 100 ms (one-time per app launch) |
| ↳ DB open + migrations | ≤ 200 ms |
| ↳ identity hydrate | ≤ 80 ms |
| ↳ provider scope construct | ≤ 20 ms |
| Velix splash → Home transition | starts after first home frame is built |

Total target: cold start ≤ 800 ms on iPhone 12 / Pixel 6, of which Flutter framework boot is the dominant cost (~250–400 ms). Our code budget is the rest.

If any phase exceeds its budget, we record a telemetry event but do not block the user. The splash holds steady (no spinner) until ready.

## State management posture

We use **Riverpod 2.x** with code generation (`riverpod_generator`). Specifically:

- `Notifier` and `AsyncNotifier` for stateful providers.
- `Provider` (computed) for selectors and reactive derivations.
- `family` modifiers for parameterized providers (per-conversation, per-user).
- `keepAlive` only when the data is genuinely long-lived; default is dispose-on-no-listeners.

Riverpod replaces both `BLoC` (which we considered) and provider-of-`ChangeNotifier` (which we rejected as imperative-overweight).

We never use `setState` inside screens for application state. `setState` is reserved for purely-local UI state (toggle of a "showing more" panel within one widget). Anything involving conversation, user, or remote data flows through Riverpod.

## Routing posture

`go_router` 14+, with code-generated typed routes. Routes are declared once and type-checked everywhere they're referenced. Each route specifies:

- A typed parameter object (if any)
- Whether it hides the floating navigation
- An accessibility label
- An optional guard (e.g., authenticated-only routes)

Imperative push happens through `VelixPageRoute` (Phase 4) — we wire `go_router`'s navigator to use it as the default route builder so every push gets the correct lateral motion + edge-swipe-back without per-call configuration.

## Performance posture

Frame stability ≥ 99% inside 16.6 ms is enforced by:
- Tight rebuild boundaries via `Consumer`/`select` patterns.
- `RepaintBoundary` around expensive painters (waveform, 3D scene, parallax layers).
- `const` everywhere possible — every component constructor is `const`-ready.
- A custom `RebuildObserver` in development that flags surfaces rebuilding more than 4× per second.

We benchmark hot paths (chat list scroll, conversation push, sheet drag) on iPhone 12 / Pixel 6 in CI. Regressions > 5% block merge.

## Banned patterns

These are forbidden across the application code (CI lint enforces where mechanically possible):

- `setState` for non-UI-local state.
- `Navigator.push(MaterialPageRoute(...))` — must use `VelixPageRoute` via `go_router`.
- `MaterialButton`, `ElevatedButton`, `TextButton` — must use `VelixButton`.
- `BottomSheet.showModalBottomSheet` — must use `VelixSheet` / `VelixModal`.
- Hard-coded colors, durations, curves — must read from `theme.velix.*`.
- `EdgeInsets.all(N)` literals — must use `context.velix.space.*`.
- `dart:ffi` outside `velix_crypto`.
- `dart:io` File access outside `velix_data` (we use the platform's `path_provider` through wrappers).
- Network calls outside `velix_data/gateways/` (centralized for testability and security review).
- `print` calls (use `velix_telemetry`).
- `DateTime.now()` outside `velix_telemetry`'s `Clock` (testability).
- Direct asset paths like `'assets/...'` outside the registry maps (`velix_3d` and `velix_motion` glyph registry).

## Read order for engineers

If you have ten minutes: 00 → 01 → 12 (audit).
If you're implementing a screen: 02 → 03 → 06 → component contracts in Phase 2 doc 09.
If you're implementing a feature: 04 → 05 → 07.
If you're auditing: 12 → 11 → 09 → everything else.
