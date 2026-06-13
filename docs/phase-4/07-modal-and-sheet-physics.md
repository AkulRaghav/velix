# 07 — Modal & Sheet Physics

The two Tier-3 surfaces with the most subtle motion engineering. Most of the perceived "Apple-grade" of the app comes from the velocity hand-off and detent-snap behavior of these two.

## `VelixModal`

A blocking surface presented over content. Fixed size; not draggable.

### Present

1. Scrim begins as transparent; runs `Curves.linear` to 60% over 240 ms.
2. Background gains 8 px additional `BackdropFilter.blur` — animated linearly over the same 240 ms.
3. Modal surface arrives via `motion.arrive` (translateY +24, scale 0.96 → 1.00, opacity 0 → 1).
4. Focus is trapped *after* the spring settles, not before — trapping focus mid-arrival creates a perceptible lag between the visual completion and the AT focus jump.
5. `VelixHaptics.modalOpen` (medium impact) fires at the moment the spring crosses 50%.

### Dismiss

1. Modal surface departs via `motion.depart` (220 ms cubic-bezier).
2. Scrim cross-fades to 0% over the same 220 ms.
3. Background blur ramps back to 0.
4. Focus returns to the invoker on dismiss start, not on dismiss complete — so AT users feel the dismiss immediately.
5. No haptic on dismiss (only on present; closing is initiated by user gesture which provides its own tactile feedback).

### Tap-scrim dismiss

A tap on the scrim outside the modal surface dismisses. The scrim is a separate `GestureDetector`. We do *not* dismiss on drag-the-scrim — that's a swipe gesture and the modal is not a sheet.

### Reduce Transparency

Scrim uses solid `surface.scrim` (no opacity); blur disabled. Same dismiss behavior.

### Reduce Motion

Single 120 ms cross-fade for the modal surface; scrim still fades; no scale, no translation.

## `VelixSheet`

A draggable Tier-3 surface that rises from the bottom edge. The most engineered widget in the system.

### Detents

A sheet declares its detents at construction. Three primitives:

```dart
enum SheetDetent { dismissed, medium, large }
```

`medium` = 50% of viewport height; `large` = 88%. A sheet may declare `[medium, large]` or `[large]` only; `dismissed` is implicit.

### Drag (vertical)

- Position follows finger 1:1 between detents — no acceleration, no smoothing.
- **Over-pull resistance** past `large` (above the largest detent): the sheet still moves but at 0.4× the finger's speed. This is the rubber-band feel.
- Over-pull below `dismissed` is undefined (the user is dragging into negative space); we clamp to `dismissed`.

### Release physics

The hardest part. On release:

1. Capture the velocity tracker's current velocity in pixels/second (positive = downward).
2. Compute the gravity-projected position: `currentPosition + velocity * 0.5` (half-second projection).
3. Snap to the detent nearest to the projected position.
4. Construct a `SpringSimulation` with:
   - `spring`: `motion.lateral` (we re-use the lateral spring for cross-detent motion)
   - `start`: current position
   - `end`: target detent position
   - `velocity`: current velocity (normalized to unit-space)
5. Run the simulation. Visual movement carries velocity through naturally.

### Threshold acceleration

If the velocity is ≥ 1200 px/s in either direction at release, the projection skips the nearest-detent rule and uses the velocity-direction next detent (one detent in the direction of motion). This is what makes a quick flick feel decisive.

### Detent locking

When the sheet is at `medium` and the user starts a drag, the sheet's detents are locked for the gesture's duration. We do not allow the user to "walk through" a detent without a release. This is how iOS sheets feel.

### Footnote: sub-detent stop

A sheet at `[medium, large]` released between the two with low velocity snaps to whichever is closer in distance. This is the only place position-based snapping wins over velocity-based.

### Dismiss

If the sheet's detent set includes `dismissed` (which it always does implicitly), and the projected position is below the `medium` detent's halfway-to-dismissed point, the sheet dismisses. `motion.depart` runs as part of the dismissal spring.

`VelixHaptics.sheetDetent` (light) fires once when the sheet snaps to a new detent — at the moment the spring crosses 50% travel, not at start or end. Dismissal does not fire a haptic (the gesture itself provides tactile feedback).

### Drag handle

A 4 × 36 px drag handle is rendered at the top of the sheet. It is **not** the only drag-affordance — the entire sheet content is draggable until the user touches a scrollable child, at which point the gesture transfers to the child's scroll. This is the iOS pattern (`UIScrollView` + `UISheetPresentationController` integration).

### Scroll-to-drag transfer

When the sheet contains a scrollable list:

1. User drags the list. The list scrolls.
2. List reaches its top (offset = 0). User continues dragging downward.
3. The drag gesture transfers from the list to the sheet, which begins to dismiss.

This is a `NestedScrollView`-equivalent integration, hand-rolled because the standard one's behavior diverges from the iOS feel. We test this transfer with golden traces — the transfer must happen within one frame of the list reaching offset 0.

### Reduce Motion

Detent transitions become 200 ms cross-fades of position (no spring); release-velocity-completion still works, but at a fixed duration. Drag still 1:1 — that's gesture-driven.

### Reduce Transparency

Same opaque-scrim treatment as modal.

### Implementation

`VelixSheet` uses a single `AnimationController` whose `value` is the position in viewport-fraction (0 = dismissed, 1 = at largest detent). The body is built with a `LayoutBuilder` to compute detent positions in absolute pixels for hit-testing.

The widget exposes:

```dart
VelixSheet({
  required Widget child,
  required List<SheetDetent> detents,
  SheetDetent initialDetent = SheetDetent.medium,
  bool dismissible = true,
  ValueChanged<SheetDetent>? onDetentChanged,
  VoidCallback? onDismiss,
})
```

## Common pitfalls (the things that go wrong if you don't engineer this carefully)

- **Velocity in wrong unit.** Flutter's velocity is px/s; spring math is unit-space. Forgetting to normalize produces under- or over-driven springs.
- **Spring re-targets without velocity preservation.** Looks fine at slow speeds; at high velocities, the new spring restarts from rest and the visual snaps. Always pass `c.velocity` when re-targeting.
- **Animating during scroll.** A sheet with a scrolling child that animates its surface during scroll fights the scroll's frame budget. We pause sheet-level animation while the inner scroll is active; the system tests for this with a synthetic 60-fps scroll-while-arriving check.
- **Double-tap haptic.** A single tap of the scrim + a fast detent-cross can fire two haptics within a frame; we de-duplicate within a 100 ms window.

## Performance contract

| Operation | Frame budget |
|---|---|
| Sheet drag at 60 fps | ≤ 4 ms / frame |
| Sheet detent transition spring | ≤ 3 ms / frame |
| Modal arrival with backdrop blur | ≤ 6 ms / frame (blur is the dominant cost; once cached, drops to ≤ 2 ms) |
| Modal dismissal | ≤ 4 ms / frame |

CI bench tests on iPhone 12 and Pixel 6 with a representative content body (settings list with 12 cells).

## Banned

- Sheets that cover content without an opaque background (you can drag-glass-on-glass which is a banned pattern from Phase 2).
- Sheets that animate during their child's scroll.
- Sheets with detents at custom positions not in the enum (we will not ship `0.62 viewport`).
- Modals that have detents (modals are fixed; if you need a detent, it's a sheet).
- Bottom-sheet-inside-bottom-sheet stacking. Use replace.
- Non-axis-aligned drag (sheets only drag vertically; modals don't drag).
