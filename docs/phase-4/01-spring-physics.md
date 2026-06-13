# 01 — Spring Physics

The system uses Hooke's-law springs (Flutter `SpringDescription` + `SpringSimulation`) for every animation that may be retargeted, dismissed mid-flight, or driven by gesture velocity. Time-curve animations (`Curves.cubic`, etc.) are reserved for one-shot, uninterruptible transits.

This document specifies the constants, the math of velocity hand-off, the rules for interruption, and the boundary between spring and curve.

## Spring constants (the "voice")

Repeated from Phase 2's `07-motion-grammar.md` for one-page reference. Every consumer reads these from `velix_design`'s `VelixMotion`:

| Pattern | Mass | Stiffness | Damping | Damping ratio | Median duration |
|---|---|---|---|---|---|
| `arrive` | 1.0 | 400 | 32 | 0.80 | 320 ms |
| `lateral` | 1.0 | 360 | 30 | 0.79 | 380 ms |
| `lift` | 1.0 | 500 | 28 | 0.63 | 240 ms |
| `settle` | 1.0 | 320 | 36 | 1.01 | 280 ms |

Damping ratios are deliberately tuned:

- `arrive` and `lateral` slightly underdamped (0.79–0.80) — a barely-perceptible settling tail makes the motion feel material rather than digital.
- `lift` more underdamped (0.63) — pickups feel responsive and a touch "alive." This is the only pattern that visibly overshoots; overshoot is < 8% as enforced.
- `settle` critically damped (1.01) — settles to rest cleanly without bounce. Releases should not be confused with arrivals.

We do not ship overdamped springs. Overdamping is sluggish.

## Velocity hand-off

The single most important Apple-grade mechanic. When a gesture releases, its velocity at release is captured and used as the initial velocity of a `SpringSimulation` toward the target.

```dart
final velocity = gesture.velocityTracker.getVelocity();
final sim = SpringSimulation(
  motion.lateral,        // SpringDescription
  position,              // current position
  target,                // target position
  velocity.pixelsPerSecond.dy / surfaceHeight, // normalized to unit-space
);
controller.animateWith(sim);
```

Three things to get right:

1. **Normalize velocity.** Spring physics work in unit-space (the controller goes 0..1). Gesture velocity is in pixels/second. Divide by the dismiss distance to convert.

2. **Choose the right pattern.** A release that intends to dismiss → `motion.depart` curve (no spring); a release that intends to settle → `motion.settle` spring; a release in lateral direction (page swipe-back) → `motion.lateral`.

3. **Cap velocity.** Real-world velocities can hit 8000 px/s on a fast flick. Cap at 4000 px/s before normalizing — beyond that, the spring is so over-driven the animation reads as warping. We do not ship physics that look like glitches.

## Interruption rules

A user can interrupt any spring at any moment. Three cases:

1. **Re-grab during animation.** If the user touches a surface mid-animation, the controller stops the simulation, captures the surface's current position, and the surface follows the finger 1:1 from there. Gesture-driven from that point.

2. **Re-target.** If a programmatic event re-targets a spring (e.g., notification arrives while a list-item is animating), we construct a new `SpringSimulation` from the *current position and velocity* of the in-flight one. We do not snap.

3. **Cancel.** If the surface needs to disappear immediately (e.g., screen unmount), the controller is disposed and the widget removed. Layout is identical pre/post — the disappearance is silent.

The runtime helper for #2:

```dart
SpringSimulation transferSpring(
  AnimationController c,
  SpringDescription s,
  double target,
) {
  return SpringSimulation(
    s,
    c.value,
    target,
    c.velocity, // velocity is preserved
  );
}
```

## Frame-rate independence

All springs are time-based, not frame-based. A 30 fps fallback (battery saver, low-end device) plays the same motion in the same wall-clock duration; only the smoothness drops. Spring math is integrated correctly through Flutter's `Ticker`.

## Time-curve animations (when, exactly)

Curves are used only for:

- **One-shot reveals** that are never interrupted (e.g., the splash mark fade-in, AI streaming token reveal, trust-state material cross-fade). These have a `motion.reveal` curve.
- **Departures** (modal dismiss, sheet close, message bubble disappear). `motion.depart` curve. These are short and the user doesn't fight them.
- **Parallax-on-scroll**. The input is itself linear gesture position, so the output is `Curves.linear`. No "physics" needed.

Anywhere the user might re-target, drag, or grab — springs.

## Damping ratio reference

For sanity:

```
ratio = damping / (2 * sqrt(mass * stiffness))
```

| Pattern | mass | stiffness | damping | ratio |
|---|---|---|---|---|
| arrive | 1 | 400 | 32 | 32 / (2·√400) = 32/40 = 0.80 |
| lateral | 1 | 360 | 30 | 30 / (2·√360) = 30/37.95 = 0.79 |
| lift | 1 | 500 | 28 | 28 / (2·√500) = 28/44.72 = 0.626 |
| settle | 1 | 320 | 36 | 36 / (2·√320) = 36/35.78 = 1.006 |

These are not numbers we tweak casually. Changes go through a design review with side-by-side video evidence on reference devices.

## Performance contract

- Single spring on a single value: < 0.05 ms / frame on iPhone 12. Negligible.
- Sheet drag with content reflow + spring + parallax background: target ≤ 2 ms / frame, audited by CI bench.
- The 99th percentile frame during a spring transition stays inside 16.6 ms on iPhone 12 and Pixel 6.

## Rejected alternatives

We considered and rejected:

- **`Animatable<T>` with cubic Bezier on every motion.** Looks fine static, breaks under interruption.
- **Material's `Curves.elasticOut`.** The overshoot is 30%+. Unusably aggressive.
- **Apple's UIKit "interpolatingSpring".** Different math; we replicate the *behavior* via Flutter's `SpringDescription`. The numbers in the table above are the result of A/B reference-screen video matching against UIKit defaults.
- **A custom physics engine.** Flutter's `physics` package ships what we need. Reinventing it costs maintenance with no upside.
