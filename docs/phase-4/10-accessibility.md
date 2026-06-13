# 10 — Accessibility (Motion)

Phase 2 established the system-wide accessibility commitments. Phase 4 specifies how the *motion layer* meets them.

## Reduce Motion behavior, exhaustive

Per pattern, when `MediaQuery.of(context).disableAnimations` is true:

| Pattern | Reduce-Motion behavior |
|---|---|
| `motion.arrive` | 120 ms `Curves.linear` opacity 0 → 1; no scale, no translation |
| `motion.depart` | 100 ms `Curves.linear` opacity 1 → 0 |
| `motion.lateral` | 200 ms `Curves.linear` opacity cross-fade between siblings; no translation |
| `motion.lift` | Scale change disabled. Material crossfade truncated to 100 ms |
| `motion.settle` | Same as `motion.lift` reverse: 100 ms crossfade |
| `motion.parallax` (tilt) | Disabled entirely |
| `motion.parallax` (scroll) | Retained — gesture-driven, not motion |
| `motion.reveal` | 200 ms `Curves.linear` opacity |
| Cinematic reveal (600 ms) | 200 ms `Curves.linear` opacity |
| Voice waveform | Bars freeze at mid-amplitude; audio still plays |
| AI streaming token reveal | Tokens appear instantly without per-token fade |
| Typing indicator | Three dots static at 0.7 opacity each; no animation |

Layout pre-state and post-state are identical with motion off. Only the *transit* changes. AT users get the same information density and the same focusable elements.

## Reduce Transparency behavior

Per pattern, when `MediaQuery.of(context).highContrast` is true:

- All glass tiers degrade to opaque equivalents (Phase 2 `02-material-tiers.md`).
- Modal scrim is opaque at 96% rather than blur-and-dim.
- Spotlight highlight becomes a 2-px solid accent border on the active element.
- 3D scenes are fallback PNGs only (Phase 3).
- Trust-state tints become 1-px borders around the conversation header.

Motion grammars themselves are unchanged in Reduce Transparency (only Reduce Motion alters them).

## Gesture timing for accessibility

Each gesture's threshold is configurable in Settings → Accessibility → Gestures:

| Gesture | Default | Available presets |
|---|---|---|
| Long-press threshold | 320 ms | 320 / 500 / 750 / 1000 ms |
| Tap cancellation distance | 16 px | 16 / 24 / 36 / 48 px |
| Pull-to-refresh threshold | 120 px | 120 / 80 / 60 px |
| Swipe-to-archive threshold | 96 px | 96 / 64 / 48 px |
| Edge-swipe-back threshold | 50% screen width | 50% / 40% / 30% |

A user with motor impairments adjusts these once and every screen respects them.

Tap-and-hold to confirm (used in destructive actions in some contexts) has its own threshold, defaulting to 1.0 s and going up to 3.0 s.

## Switch Control / Switch Access

Every visible motion can complete on its own without user gesture. Switch users do not have to "hold" a swipe — instead:

- Sheet present has both a "Open Sheet" and "Dismiss Sheet" Semantics actions.
- Page push has a custom action equivalent for back navigation.
- Long-press menu has explicit "Show menu" action.
- Story navigation has "Next story", "Previous story", "Dismiss" actions.

These are exposed via `Semantics(customSemanticsActions: ...)` so Switch and Voice users access the same affordances as gesture users.

## Voice Over (iOS) and TalkBack (Android) — animation timing

Some animations have AT implications:

| Animation | AT behavior |
|---|---|
| `motion.arrive` of a modal | Focus trapped *after* spring settles (380 ms) so AT focus jump aligns with visual completion |
| `motion.depart` of a modal | Focus returns to invoker *immediately* on dismiss start (not on dismiss complete) |
| Page push | New screen's first focusable element receives focus after `motion.lateral` settles |
| Page pop (gesture-driven) | Focus returns to the previous screen's last focused element on commit, not on gesture release |
| Story open | Story author + first description announced as scene reaches fullscreen |
| Voice waveform during recording | "Recording, {n} seconds" announced once per second via LiveRegion |
| AI streaming response | "AI thinking" on first token; "{response}" on stream close (not per token) |
| Typing indicator appears | "{name} is typing" once; not re-announced |

These timings are coded into the relevant motion widgets, not left to ad-hoc handling.

## Vestibular sensitivity

Beyond Reduce Motion (which removes parallax and bounce):

- Bounce overshoot is capped at 8% across the system, well below thresholds known to trigger vestibular issues.
- The 3D system's drift is 18–48 s slow and bounded amplitude, well within safe parameters.
- No animation auto-replays without a gesture.

Photosensitivity:
- No animation produces global luminance changes > 30% within 200 ms.
- The 3D pipeline rejects assets that violate this (Phase 3).

## Cognitive load

Motion is paced to be predictable. The seven patterns are the entire vocabulary; users learn them implicitly within 3–5 sessions. We measure this:

- Beta users describe transitions as "smooth" without asking what they were.
- Users do not report "this app is too animated."
- Users with cognitive accessibility needs (autism spectrum, ADHD) can identify the system's calm posture in qualitative interviews.

## Performance and accessibility

Reduce Motion is *also* a performance feature on low-end devices. When motion is reduced, GPU and CPU frame budget drops by ~3 ms per frame in our hot paths. We do not rely on this — the budget is met with motion on.

But: when a device is in low-power mode (iOS) or battery saver (Android), the platform automatically enables Reduce Motion. We honor this; the visual experience degrades gracefully.

## Statement (public)

The accessibility statement at `velix.app/accessibility` includes:

- Full Reduce-Motion matrix per pattern
- Gesture-threshold configurability list
- Switch / Voice Access compatibility statement
- Photosensitivity statement
- Per-platform AT testing pledge (VoiceOver, TalkBack, Switch Control on iPad and Android)

## Audit checklist (Phase 4 close)

- [ ] Every pattern has a Reduce-Motion variant verified by golden-trace test
- [ ] Reduce-Transparency tested on every screen with the motion library mounted
- [ ] Gesture thresholds configurable; Settings UI tested with VoiceOver
- [ ] Long-press alternative (tap-then-tap) available where ergonomic
- [ ] AT focus timing verified for modal arrive/dismiss, page push/pop
- [ ] Photosensitivity check passes for all motion (≤ 30% luminance change / 200 ms)
- [ ] Bounce overshoot ≤ 8% verified per pattern
- [ ] Typing indicator's `LiveRegion` does not fire repeatedly
- [ ] AI streaming does not announce per-token
- [ ] Haptics suppressed when OS settings disable; verified
- [ ] Reduce-Motion fallback durations ≤ 200 ms across the table
