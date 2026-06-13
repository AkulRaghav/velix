# 07 — Motion Grammar

Motion is the most often-faked aspect of "premium" UI. Most products animate everything; the result is busy and tiring. Apple's discipline is the opposite — motion is sparse, but every motion is **physical**, **intentional**, and **interruptible**.

We define **seven** patterns. Together they are the system's full motion vocabulary. Adding an eighth requires a formal review.

## Principles

1. **Physical.** All motion uses spring physics or carefully tuned cubic-bezier curves. No linear motion. No bounce-for-bounce's-sake.
2. **Interruptible.** Every animation must be cancelable mid-flight without visual glitch. We use spring physics so a re-target during animation is naturally damped.
3. **Decisive.** Animations are short. The longest in the grammar is 480 ms (full modal dismissal). Most are under 280 ms.
4. **Driven.** Motion responds to gesture velocity. A fast swipe-to-dismiss completes faster than a slow one. We pass gesture velocity into the spring as initial velocity rather than restarting from zero.
5. **One pattern per role.** A "modal arrives" looks the same in every modal. We do not invent variants per screen.
6. **Reduce-Motion respected.** When the OS reports `MediaQuery.disableAnimations`, every spring degrades to a 120 ms cross-fade. Layout never jumps.

## The seven patterns

### 1. `motion.arrive` — a thing comes in
Used for: modal presentation, sheet open, message bubble first paint, story open.

- Translation: 24 px upward (vertical slide-in)
- Scale: 0.96 → 1.00
- Opacity: 0 → 1
- Curve: spring(stiffness 400, damping 32, mass 1)
- Median duration: 320 ms
- Reduce-Motion: 120 ms cross-fade, no translation, no scale

### 2. `motion.depart` — a thing leaves
Used for: modal dismiss, sheet close, message bubble disappear.

- Translation: down 24 px (vertical slide-out)
- Scale: 1.00 → 0.98
- Opacity: 1 → 0
- Curve: cubic-bezier(0.4, 0.0, 1.0, 0.5) — accelerate-in
- Duration: 220 ms (faster than arrive — exits feel snappier)
- Reduce-Motion: 100 ms fade

### 3. `motion.lateral` — a thing slides between siblings
Used for: page navigation, story sibling swipe, conversation swipe-to-archive.

- Translation: ±screen-width
- Opacity: incoming 0.6 → 1.0; outgoing 1.0 → 0.6
- Curve: spring(stiffness 360, damping 30, mass 1)
- Duration: 380 ms with default velocity; gesture-driven duration scales 200–500 ms
- The outgoing layer's opacity dip prevents a flat-card-shuffle look; it implies parallax.

### 4. `motion.lift` — a thing rises in Z
Used for: tap-and-hold reaction picker, draggable list item pickup, voice-message preview.

- Translation: 0 (no movement)
- Scale: 1.00 → 1.04
- Elevation: from current to current + 1
- Material: ascends one tier
- Curve: spring(stiffness 500, damping 28, mass 1)
- Duration: 240 ms
- Reverse on release uses `motion.settle`.

### 5. `motion.settle` — a thing returns to rest
Used for: reverse of `motion.lift`, drag-cancel return, message bubble settling after send.

- Curve: spring(stiffness 320, damping 36, mass 1) — slightly more damped than lift
- Duration: 280 ms
- Material descends one tier
- Velocity carry: yes (pick up gesture velocity for natural release)

### 6. `motion.parallax` — depth-aware scroll response
Used for: profile hero with avatar/banner, story progress backdrop, full-screen call when remote video moves slightly with device tilt.

- Two-layer parallax: foreground 1.0× scroll, background 0.7× scroll.
- Three-layer for splashes/onboarding: 1.0×, 0.85×, 0.55×.
- Always linked to scroll/tilt offset, never time-driven.
- This is the only place we use linear motion — because the input is itself linear gesture position.

### 7. `motion.reveal` — substance becoming visible
Used for: trust-state material change, call-connect scene materialization, AI streaming token reveal, story progress ring fill.

- Material change: opacity ramp on the new material (0 → 1) with the old at 1 → 0, 240 ms.
- For the trust-rekeyed state, an additional sub-pixel surface tremor is overlaid (see `material.modifier.tremor`).
- For AI streaming, each token fades in over 60 ms with a 12 ms delay between tokens.
- Curve: cubic-bezier(0.2, 0.0, 0.0, 1.0) — slow start, fast end (the "things become real" feel).

## Tokens (Flutter)

Each pattern is exposed as a typed motion record:

```dart
class VelixMotion {
  final SpringDescription arrive   = const SpringDescription(mass: 1, stiffness: 400, damping: 32);
  final Curve              depart   = const Cubic(0.4, 0.0, 1.0, 0.5);
  final SpringDescription lateral  = const SpringDescription(mass: 1, stiffness: 360, damping: 30);
  final SpringDescription lift     = const SpringDescription(mass: 1, stiffness: 500, damping: 28);
  final SpringDescription settle   = const SpringDescription(mass: 1, stiffness: 320, damping: 36);
  final Curve              reveal   = const Cubic(0.2, 0.0, 0.0, 1.0);
}
```

All durations exposed as `Duration` constants:

```
motion.duration.arrive   = 320 ms
motion.duration.depart   = 220 ms
motion.duration.lateral  = 380 ms
motion.duration.lift     = 240 ms
motion.duration.settle   = 280 ms
motion.duration.reveal   = 240 ms
motion.duration.reduceMotionFallback = 120 ms
```

## Motion roles per surface

| Surface | Patterns it uses |
|---|---|
| Splash | `reveal` (single use, pure cinematic) |
| Onboarding step transition | `lateral` |
| Onboarding hero element entry | `arrive`, `parallax` |
| Login → Home | `arrive` for home (root replacement) |
| Floating nav tab change | spotlight reveal + icon `tab-active` (icon motion 6) |
| Conversation push | `lateral` |
| Modal | `arrive` / `depart` |
| Bottom sheet | `arrive` / `depart` (with detents) |
| Tap-and-hold reaction | `lift` / `settle` |
| Message send | `arrive` (subtle, no scale change) |
| Story open / close | `lift` then `arrive` for content |
| Call connect | `reveal` (the full scene materializes) |
| Voice recording → send | `lift` then `arrive` of the voice waveform bubble |
| AI streaming | `reveal` (token-by-token) |
| Trust state change | `reveal` (material crossfade) |

## Velocity hand-off (Apple-style spring transfer)

When a user gesture transitions into a programmatic animation (e.g., releasing a swipe-to-dismiss), the *velocity* of the user's finger is passed into the destination spring's initial velocity. This is what makes Apple's gesture animations feel uncanny — the system continues your motion rather than starting a new motion.

We implement this in Flutter via `SpringSimulation` constructed with a custom `velocity` parameter from the gesture's last `velocityTracker` reading.

## Gesture-driven (vs time-driven) animations

Velix prefers gesture-driven animations whenever a user is in contact with the surface. The user *is* the animator until they release.

- Swipe-to-dismiss on a sheet: position follows finger 1:1 until release.
- Pull-to-refresh on chat list: tension increases as the user pulls past the threshold; release triggers `motion.lift` then `motion.settle` for the refresh.
- Story progress: tap-pause is instant; drag-scrub follows the finger.

Time-driven animations (a button bouncing on tap, a message bubble appearing) use the spring tokens.

## Loops and idle motion

We have **three** allowed loops in the entire system:

1. **Voice waveform during recording or playback** — driven by audio amplitude, not time.
2. **Typing indicator** — three dots, 1.4 s loop, signature-accent dim.
3. **AI streaming token reveal** — driven by token arrival, not by a metronome.

Everything else — pulses on idle buttons, breathing call-to-action banners, rotating splash logos — is **forbidden**.

## Banned motion patterns

- Linear easing on time-driven animation. (`Curves.linear` only allowed for parallax-on-scroll.)
- Bounce overshoot greater than 8% (`overshootClamping` should be true beyond that).
- "Magic move" between unrelated screens. We use system patterns.
- Stagger animations on lists with > 8 visible items (it becomes a Christmas tree).
- Letter-spacing or weight animations on text.
- Color-rotation animations on idle elements (we are not a Web Awards site).
- Animations longer than 500 ms.
- Animations during a scroll. (Animations pause; finish on scroll-end.)

## Performance budget

Each pattern is benchmarked. Any pattern that drops a single frame on a 2022-era mid-tier Android during normal use is rebuilt or removed.

The hard rule: **frames stay ≤ 16.6 ms throughout every animation in the grammar**, including the moment of motion start (the most likely frame to drop).

## Reduce Motion behavior summary

When `MediaQuery.disableAnimations` is true, the entire grammar collapses to:
- 120 ms opacity-only cross-fade
- No spatial movement, no scale changes
- Motion grammar tokens still resolve (so layout pre-/post-state is identical), but their durations and offsets are zeroed.

Every screen is verified to be fully usable in this mode.
