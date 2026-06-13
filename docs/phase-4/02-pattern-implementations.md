# 02 — Pattern Implementations

The seven Phase-2 patterns turned into Flutter widgets. Each section is the contract for the widget; the production code lives in `packages/velix_motion/` and tests verify the contract.

## `VelixArrive` — pattern `motion.arrive`

A child appears: translates 24 px from below + scales 0.96 → 1.00 + opacity 0 → 1, springs to rest.

### API

```dart
VelixArrive({
  required Widget child,
  bool present = true,           // toggle to drive in/out
  Duration delay = Duration.zero,
  VoidCallback? onArrived,
})
```

### Implementation

A single `AnimationController` driven by a `SpringSimulation` using `motion.arrive`. Three transforms applied in `Transform` + `Opacity`:

- translateY from `+24` to `0`
- scale from `0.96` to `1.00`
- opacity from `0` to `1`

When `present` flips to false, runs `motion.depart` to the inverse end-state (translateY `+24`, scale `0.98`, opacity `0`). On second present-true, restarts from the current position with velocity hand-off.

### Reduce Motion

Single 120 ms `Curves.linear` opacity fade; no translation, no scale.

### Used by

Modal arrivals, sheet open, story content paint, message bubble first-paint (subtle variant — no scale, only translation).

---

## `VelixDepart` — pattern `motion.depart`

A child leaves: translates 24 px down + scale 1.00 → 0.98 + opacity 1 → 0, accelerating curve.

Conceptually the inverse of `VelixArrive`. The widget composes both — `VelixArrive` already handles departure when `present` flips to false. Standalone `VelixDepart` exists for cases where the child is a separate route that's already mounted (rare).

### Reduce Motion

100 ms opacity fade.

---

## `VelixLateral` — pattern `motion.lateral`

A child slides between siblings, with parallax of opacity. Used at the level of pages and stories.

### API

```dart
VelixLateral({
  required Widget child,
  required AxisDirection direction,    // left, right, up, down
  required double progress,            // 0..1, externally driven
  bool gestureDriven = false,
})
```

The widget is *driven* — the caller provides progress. For programmatic `motion.lateral`, callers wrap the controller's `value` into the widget; for gesture, the gesture handler passes `progress`. Two modes, one widget.

### Implementation

- Translation from `±screen-extent * (1 - progress)` to `0`
- Opacity: `0.6 + 0.4 * progress`

For the *outgoing* sibling, an inverse `progress` is passed; the same widget handles both directions.

### Reduce Motion

200 ms opacity cross-fade; no translation.

### Used by

`VelixPageRoute`, story sibling navigation, conversation swipe-to-archive.

---

## `VelixLift` and `VelixSettle` — patterns `motion.lift` / `motion.settle`

A surface rises in Z (lift), or returns to rest (settle). Lift is paired: it always reverses to settle, never re-uses the lift physics.

### API

```dart
VelixLift({
  required Widget child,
  required bool lifted,            // toggle drives lift / settle
  double scaleAmount = 0.04,       // 1.00 → 1.04 default
  ZTier? destinationTier,          // used for shadow ramp
})
```

### Implementation

- Scale from `1.00` to `1.0 + scaleAmount`
- Shadow ramps from `elevation.0` (or current) to `elevation.2`
- If `destinationTier` is `ZTier.modal`, additionally crossfade the child's wrapping material from current to Tier-3 lifted

When `lifted` flips false, the same controller reverses through `motion.settle` (not `motion.lift`'s inverse — settle is more damped). Velocity hand-off retained.

### Haptics

Lift fires `VelixHaptics.lift` (medium impact) at the moment of the spring's first frame past 50% travel. Settle does not fire haptics.

### Reduce Motion

Scale change disabled. Shadow ramp truncated to 100 ms cross-fade.

### Used by

Tap-and-hold reaction picker source bubble, draggable list-item pickup, voice-message preview, send-button compress.

---

## `VelixParallax` — pattern `motion.parallax`

Two- or three-layer parallax bound to scroll or device tilt. The only place we use linear easing (the input is itself linear).

### API

```dart
VelixParallax({
  required List<ParallaxLayer> layers,
  required ScrollController? scroll,
  bool useTilt = false,
})
```

```dart
class ParallaxLayer {
  final Widget child;
  final double factor; // 1.0 = locked to input, 0.0 = stationary
}
```

### Implementation

For each layer, transform translation by `inputOffset * factor`. Inputs:

- Scroll: `scroll.offset`, low-passed at 60 Hz.
- Tilt: device gyro, low-passed at 120 ms time constant, mapped to a small (±12 px) offset.

Combined when both active.

### Reduce Motion

Tilt parallax disabled. Scroll parallax retained (it's gesture-driven).

### Used by

Profile hero, story progress backdrop, splash gradient, video-call participant tile (subtle).

---

## `VelixReveal` — pattern `motion.reveal`

Substance becoming visible. Curve: `cubic-bezier(0.2, 0.0, 0.0, 1.0)` — slow start, decisive end.

### API

```dart
VelixReveal({
  required Widget child,
  required bool revealed,
  Duration duration = const Duration(milliseconds: 240),
})
```

### Implementation

A simple `AnimatedOpacity`-equivalent driven by the reveal curve, with a special-case that holds at 0 opacity while not yet revealed (so the underlying widget tree is built but not visible — important for accessibility tree continuity).

### Reduce Motion

200 ms `Curves.linear` opacity.

### Used by

Trust-state material cross-fade, AI streaming token reveal (per-token), call-connect scene materialization, story progress ring fill.

---

## Composability rules

1. Patterns can be nested but the *outermost* pattern owns timing. A `VelixLift` child should not be a `VelixArrive`; pick one. (Smoke tests check for this in development.)

2. Patterns share an `AnimationController` if and only if they animate the same property. We do not double-animate scale via two stacked widgets.

3. `Hero` is *not* used in Velix. We hand-roll element transitions inside `VelixPageRoute` because `Hero` is hard to interrupt. Documented as banned in `06-navigation-transitions.md`.

## Token references (Phase 2)

Every widget reaches Phase 2 motion tokens via `context.velix.motion` — never hard-coded durations or curves. Lint flag against `Duration(milliseconds: ...)` literals in widget code.

## Performance audit

For each widget:

- Render cost ≤ 0.5 ms / frame on iPhone 12 in worst case (`VelixArrive` of a complex card with shadow).
- 99% frame stability inside 16.6 ms across the duration of the animation.
- Interruption test: pause the animation at 30%, 60%, 90% — visual continuity verified by golden image diff with tolerance < 0.5%.
