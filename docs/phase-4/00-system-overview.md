# 00 — Motion System Overview

## Position

Phase 2 specified the seven motion patterns. Phase 4 implements them, plus the realtime motions, the gestures, the navigation transitions, the modal and sheet physics, the scroll system, and the haptics coordination. Together this is the *behavior layer* of Velix. Tokens decide how things look; this layer decides how they feel.

The bar is Apple. The reference for "feels right" is iOS 17 — interrupting a sheet drag mid-flight, releasing a swipe-back partially through, watching a tap propagate scale-press → release without overshoot, and noticing nothing — because nothing is wrong.

## Core principles

1. **Physical, not aesthetic.** Animation parameters are derived from physics constants we believe in (mass, stiffness, damping). They are not "this looks nice." When a value changes, the change is justified physically.

2. **Interruptible everywhere.** Every animation can be cancelled mid-flight without visual glitch. Springs handle this naturally; we use them for any animation that might be retargeted.

3. **Velocity hand-off.** Whenever a user gesture transitions to a programmatic animation, the gesture's release velocity flows into the spring as initial velocity. This is the single most important Apple-grade mechanic. We use it for: sheet dismiss, modal dismiss, swipe-back, pull-to-refresh, drag-to-archive.

4. **Gesture-driven first.** When the user is touching the surface, the user is the animator. Programmatic animation only takes over on release.

5. **Calm, not flashy.** No animation longer than 500 ms (one 600 ms cinematic exception per screen visit). No bounce overshoot greater than 8%. No animations during scroll.

6. **Frame budget aware.** All motion fits inside the 16.6 ms frame budget on reference devices (iPhone 12, Pixel 6). 99% frame stability is enforced by CI on the hot paths (chat list arrivals, conversation push, sheet drag).

7. **Haptics are part of motion.** A spring resolves with a haptic; a modal opens with a haptic; a long-press lifts with a haptic. Haptics never fire without coordinated visual motion, and never fire ad-hoc from leaf widgets.

8. **Reduce Motion respected.** Every pattern has a 120 ms cross-fade fallback. Layout is identical; only the transit changes.

## What's hand-coded vs what's Rive

| Hand-coded (Flutter) | Rive |
|---|---|
| All seven Phase-2 motion patterns (arrive, depart, lateral, lift, settle, parallax, reveal) | Eight identity glyphs |
| Voice waveform (audio amplitude → CustomPainter) | AI assistant spark animation |
| AI streaming token reveal | Encryption-shield trust-state morph |
| Typing indicator (three dots, the only stylistic loop) | Voice mic recording-state animation |
| Page transitions, modal physics, sheet detents | Loader.spinner.cinematic (the splash glyph reveal) |
| Scroll physics, pull-to-refresh, swipe-to-archive | n/a |
| Drag-and-drop, long-press, gesture dismiss | n/a |
| Haptics coordinator | n/a |

The split is principled: **hand-coded for everything that responds to Flutter state, Rive for everything that is a self-contained character motion**. A typing indicator is hand-coded because it must respond to "user started/stopped typing" state. A glyph that fades and morphs through three trust states is Rive because the animation is its own state machine that doesn't change between users.

We don't use Rive for everything because:
- Rive runtime adds 2 MB of binary for things we don't need (state machine evaluator, Bezier rasterizer, IK).
- Hand-coded motion can integrate Phase 2 tokens, springs, and haptics directly without translation.
- Designers can iterate on Rive glyphs without engineering, but everything else benefits from the discipline of fitting the Phase 2 token system.

## Banned (system-level)

Restated from Phase 2's `07-motion-grammar.md`, with Phase 4 specifics:

- Linear easing for time-driven animation (parallax-on-scroll only).
- Bounce overshoot greater than 8%; default `overshootClamping: true` past that.
- "Magic move" between unrelated screens — we use the system patterns.
- Stagger animations on lists with > 8 visible items (turn into a Christmas tree).
- Letter-spacing or weight animations on text.
- Idle pulses, breathing CTAs, rotating icons.
- Animations during scroll (animations pause; finish on scroll-end).
- Animations longer than 500 ms (cinematic 600 ms exception, used at most once per qualifying event).
- Loops outside the three permitted (waveform, typing, AI streaming) — and even those are input-driven, not metronomic.
- Haptics fired without coordinated visual motion.
- Custom navigation transitions outside `VelixPageRoute`.
- Custom dismissable physics outside `VelixModal` / `VelixSheet`.

## What good looks like

Some markers we audit for, both manually and via golden-trace tests:

- A bottom sheet at half-detent, dragged 80% toward dismissal, released — completes dismissal because gesture velocity carries it through the spring.
- The same sheet released at 30% — springs back to half-detent with the same gesture velocity damped naturally.
- A long-press on a chat bubble — bubble lifts (`motion.lift`), reaction picker arrives at Z3 (`motion.arrive`), haptic fires once at the moment of lift.
- Pull-to-refresh — finger drags resistance scales sub-linearly, release triggers refresh with `motion.lift` then `motion.settle`, haptic on threshold cross.
- Page push to a conversation — `motion.lateral`, ~380 ms, but if the user immediately swipes back at 50% the swipe drives the same animation in reverse with no animation overlap.

## What ships in Phase 4

A tested, lint-clean Flutter package that other packages depend on for behavior. Specifically:

- All seven motion patterns wrapped in widgets and tested.
- `Waveform`, `AIStreamingText`, `TypingIndicator` widgets.
- `VelixPageRoute`, `VelixModal`, `VelixSheet`, `VelixScrollPhysics`.
- `VelixHaptics` coordinator with a small typed event API.
- `VelixGlyph` widget that loads from a `.riv` registry; the eight glyphs themselves are authored in Phase 5 alongside the assets pipeline.
- Smoke + golden + behavior tests covering the hot paths.
- Reduce-Motion variants verified for every pattern.
- Per-platform haptics mapping verified (iOS UIKit feedback generator, Android `HapticFeedbackConstants`).
