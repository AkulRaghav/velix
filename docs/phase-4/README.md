# Phase 4 — Motion & Interaction System

Status: in progress. Gates Phase 5.

## What this phase delivers

The seven Phase-2 motion patterns are *specified* in Phase 2. Phase 4 turns each into a working, audited Flutter widget — plus the realtime motions (voice waveform, AI streaming, typing indicator), the haptics coordination layer, the page-transition system, the modal and sheet physics, the scroll-behavior rules, and the gesture-velocity hand-off mechanics that make Velix feel Apple-grade.

Rive joins the system as the authoring tool for two specific things: the **eight custom identity glyphs** and **specialized character motion** that would be expensive to hand-code (the encryption-shield's micro-tremor states, the AI assistant spark glyph, the voice mic glyph). Everything else is hand-coded Flutter using `physics`, `AnimationController`, and `CustomPainter`.

## Locked posture

- Animations are short, decisive, and physical. Maximum 500 ms in the grammar; one cinematic exception at 600 ms.
- Gesture-driven > time-driven where the user is in contact with the surface.
- Velocity hand-off from gesture to spring is mandated for every dismissable surface.
- Reduce Motion is honored at the system level; layout is identical with motion off.
- No invented motion grammar per screen. The seven (plus three realtime cases) are the entire vocabulary.
- Haptics are coordinated with motion through a single coordinator, never invoked ad-hoc.

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Motion System Overview](./00-system-overview.md) | Philosophy, what's in / out, Rive vs hand-coded |
| 01 | [Spring Physics](./01-spring-physics.md) | Constants, hand-off math, interruption rules |
| 02 | [Pattern Implementations](./02-pattern-implementations.md) | The seven Phase-2 patterns realized as widgets |
| 03 | [Realtime Motion](./03-realtime-motion.md) | Waveform, AI streaming, typing indicator |
| 04 | [Identity Glyph Animation](./04-identity-glyph-animation.md) | The eight custom glyphs, Rive integration |
| 05 | [Gestures](./05-gestures.md) | Drag, swipe, long-press, pinch — uniform behavior |
| 06 | [Navigation Transitions](./06-navigation-transitions.md) | Page push/pop, replacement, hero-equivalent |
| 07 | [Modal & Sheet Physics](./07-modal-and-sheet-physics.md) | Detent springs, gesture dismiss, focus trap timing |
| 08 | [Scroll Behavior](./08-scroll-behavior.md) | Per-platform physics, parallax, pull-to-refresh, decel |
| 09 | [Haptics Coordination](./09-haptics-coordination.md) | The single coordinator; what events fire what |
| 10 | [Accessibility](./10-accessibility.md) | Reduce Motion behavior per pattern, AT timing |
| 11 | [Phase 4 Audit](./11-phase-4-audit.md) | Self-review, gates Phase 5 |

## Reference implementation

`packages/velix_motion/` — the runtime motion library. Composes Phase 2 tokens (`velix_design`) and exposes:

- `VelixMotionWidget` family — typed widgets implementing the seven patterns
- `Waveform`, `AIStreamingText`, `TypingIndicator` — the realtime three
- `VelixPageRoute` — the navigation transition
- `VelixModal` and `VelixSheet` — the Tier-3 surfaces with detent physics
- `VelixHaptics` — the coordinator
- `VelixScrollPhysics` — per-platform tuned physics

Rive integration is a thin wrapper (`VelixGlyph`) that loads `.riv` assets from a registry. The eight `.riv` files themselves are authored in Phase 5; Phase 4 establishes the contract.

## Reading order

If you have ten minutes: 00 → 02 → 11.
If you're implementing a screen: 02 → 06 → 07 → 09.
If you're auditing: 11 → 10 → 01 → 02 → 03.
