# 05 — Gestures

A small, uniform set of gesture behaviors. Each gesture has a typical visual response, a typical haptic, and a documented threshold. The goal: any user can predict how Velix reacts to their fingers because the system is consistent.

## The catalog

| Gesture | Used for | Visual response | Haptic |
|---|---|---|---|
| Tap | Primary activation | scale 0.97, spring back | `light` on press |
| Long-press (≥ 320 ms) | Reaction picker, list-item pickup, secondary menus | `motion.lift` to Z2.5 + reveal at Z3 | `medium` on lift |
| Drag (vertical) | Bottom-sheet detents, pull-to-refresh, vertical reorder | Position follows finger 1:1 | depends on context |
| Drag (horizontal) | Page swipe-back, conversation swipe-archive, story sibling | Position follows finger 1:1; opacity-parallax of incoming sibling | none on drag |
| Swipe (flick) | Same as drag, but velocity carries through | Velocity-driven spring completion | `light` on completion |
| Pinch | Story zoom only (one place in the app) | Scale-with-resistance, spring back at release | none |
| Two-finger pan | Story horizontal-scrub during pinch | Position follows finger | none |
| Edge swipe | iOS-style back navigation | `motion.lateral` reverse, gesture-driven | `light` on completion |

That's it. Custom gestures are not allowed without a Phase-N revision.

## Tap

The simplest, most-used gesture. Has the strictest accessibility requirement (48 × 48 hit-target minimum, see Phase 2 `12-accessibility.md`).

### Visual

- Press: scale 1.00 → 0.97 over 100 ms via `motion.lift` partial (no Z change)
- Release: spring back to 1.00 via `motion.settle`

### Haptic

- `light` on the press frame, never on release
- Suppressed when the underlying widget is disabled

### Behavior

- Cancellation: drag distance > 16 logical px before release cancels the tap. The press-down visual reverts via `motion.settle`.
- Secondary tap-areas for accessibility (e.g., a 32-px avatar with a 48-px hit region) use the same press visual on the entire region, not the visible avatar.

## Long-press

A gesture explicitly distinct from tap. The 320 ms threshold is a Velix constant (not Apple's 500 ms default — too long, makes the system feel slow; not Android's 200 ms — too short, false positives).

### Visual

- 0–100 ms after touch-down: nothing visible.
- 100–320 ms: subtle scale 1.00 → 0.99 (the user feels the system pre-loading their gesture).
- 320 ms: `motion.lift` engages, reaction picker / context menu reveals at Z3.

### Haptic

- `medium` impact at the 320 ms threshold cross. Never at touch-down.

### Behavior

- Drag during long-press (after threshold) controls a 1:1 cursor over context-menu items.
- Lift during 100–320 ms is treated as a tap.
- Lift after 320 ms is treated as a select on the highlighted item (if any) or dismiss (if no item).

## Drag (vertical) — bottom sheet & pull-to-refresh

The most engineered gesture. Three sub-cases.

### Bottom sheet

- Position follows finger 1:1 between dismiss and target detent.
- Soft over-pull resistance: past the largest detent, the sheet still moves but at 0.4× the finger's speed (the rubber-band feel).
- Release at velocity ≥ 1200 px/s carries through to the next detent in the velocity direction (regardless of position).
- Release below threshold velocity snaps to the nearest detent via spring with velocity hand-off.

### Pull-to-refresh

- Resistance: at offset 0–80 px, scroll moves 1:1. Past 80 px, the scroll moves 0.5× the finger.
- Threshold: 120 px logical.
- At threshold cross, `light` haptic fires once.
- Release past threshold: refresh fires; the spinner reveals via `motion.lift` then `motion.settle` after refresh completes.
- Release before threshold: scroll springs back to 0 with velocity hand-off.

### Vertical reorder (within a list)

- Long-press to lift (`medium` haptic at lift moment).
- Drag follows finger 1:1.
- Hover over a position past the midpoint of an adjacent cell triggers a spring-driven cell shift (`motion.lateral`) and a `light` haptic.
- Release: the lifted item drops with `motion.settle`.

## Drag (horizontal) — page swipe-back, conversation swipe-archive, story sibling

### Page swipe-back

- Edge swipe gesture from left edge (LTR) or right edge (RTL).
- Position follows finger 1:1 across the screen width.
- Threshold: 50% of screen width OR velocity ≥ 1200 px/s in the swipe direction.
- Below threshold release: spring back to current page.
- Above threshold release: complete `motion.lateral` to previous page with velocity hand-off; `light` haptic on completion.

### Conversation swipe-archive

- Swipe from right (LTR) on a chat-list cell.
- Position follows finger 1:1.
- Threshold: 96 px (the width of the action affordance) OR velocity ≥ 1200 px/s.
- Below threshold: spring back; cell remains.
- Above threshold: action committed; cell exits via `motion.depart` to the right; `light` haptic on commit.

### Story sibling

- Horizontal swipe within story viewer.
- Position follows finger 1:1 across the screen.
- Threshold: 30% of screen width OR velocity ≥ 800 px/s.
- Below threshold: spring back to current story.
- Above threshold: advance to sibling with `motion.lateral` and parallax of the underlying media at 0.85× factor.

## Swipe (the flick variant of drag)

A swipe is a drag with velocity. The gesture handler is the same; only the release-time velocity check differs. We do not have separate "swipe gestures" — every swipe is a drag with momentum.

## Pinch (story zoom only)

The one place in Velix that uses pinch.

- Scale 0.5–4.0 with resistance past the bounds.
- Two-finger pan during pinch translates within the zoomed image.
- Release: spring back to 1.0 with velocity hand-off; if the user pinched out and released, scale stays at the zoom; double-tap returns to 1.0.

We do not use pinch for any other surface. A user pinching a chat list does nothing (intentionally); we do not produce surprising responses.

## Edge swipe — iOS gesture compatibility

iOS users expect edge swipe from the left edge to invoke back-navigation. We honor it via `VelixPageRoute`'s built-in support, identical to system behavior.

We do not implement an iOS-style "swipe-from-bottom-edge to go home" — that's the OS's gesture and we don't intercept it.

## Gesture latency targets

| Gesture | Latency from touch to first visual response |
|---|---|
| Tap (press visual) | ≤ 16 ms (one frame) |
| Long-press pre-lift hint | ≤ 100 ms |
| Long-press lift | 320 ms (deliberate) |
| Drag (any) | ≤ 16 ms (one frame) |
| Pinch | ≤ 16 ms |
| Swipe-back complete | ≤ 16 ms after release; spring duration governed by `motion.lateral` |

These are measured in CI on iPhone 12 and Pixel 6. Regressions block merge.

## Conflicting gestures

Some surfaces have ambiguous gestures. We resolve via priority:

| Surface | Primary | Secondary |
|---|---|---|
| Chat list cell | tap (open conversation) | swipe-archive (right-edge), long-press (mute) |
| Message bubble | tap (no-op for non-link content) | long-press (reaction picker) |
| Bottom sheet | drag (resize/dismiss) | tap-scrim (dismiss) |
| Story viewer | tap-left/right (advance/back) | drag-vertical (dismiss), drag-horizontal (sibling) |
| Story viewer mid-pinch | pinch (zoom) | two-finger pan (translate within zoom) |

A single gesture surface never claims more than two primary gestures. Tertiary affordances must be exposed via explicit UI (a "Mute" toggle in conversation header, etc.).

## What if the user has motor impairments?

- Long-press threshold is configurable in Accessibility settings: 320 / 500 / 750 / 1000 ms.
- Tap cancellation distance is configurable: 16 / 24 / 36 / 48 px.
- Pull-to-refresh threshold is configurable: 120 / 80 / 60 px.

Settings → Accessibility → Gestures.

## Banned gestures

- Triple-tap, quadruple-tap (forgettable, unreliable).
- Force touch / 3D touch (deprecated by Apple, was always a discoverability problem).
- Two-finger tap (Apple OS-reserved on macOS for right-click).
- Shake-to-undo (jarring; we use a Toast undo instead).
- Long-press on a tab to invoke menus (tab bar tabs do not have long-press menus).
- Custom gestures invented per-screen.

## Implementation notes

All gestures use Flutter's `GestureDetector` and `RawGestureDetector` where needed. Custom recognizers (e.g., the long-press-with-velocity-tracking) are typed and tested in `velix_motion`.

The gesture system holds a single `VelocityTracker` per active gesture for hand-off to `SpringSimulation` on release.
