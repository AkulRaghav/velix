# 06 — Navigation Transitions

Routing animations are easy to over-engineer. Velix uses a single, principled set.

## The route types

| Route | When | Pattern |
|---|---|---|
| **Push** | Forward navigation (Home → Conversation, Settings → Privacy) | `motion.lateral` rightward (RTL: leftward) |
| **Pop** | Back navigation | `motion.lateral` reverse, gesture-driven if edge-swipe |
| **Replace** | Auth → Home, Logout → Login | `motion.arrive` of new root + `motion.depart` of old |
| **Modal present** | Tier-3 surfaces (Sheet, Modal) | `motion.arrive` upward + scrim |
| **Modal dismiss** | reverse | `motion.depart` downward + scrim un-dim |
| **Story open** | Tap story | `motion.lift` (story tile lifts to fullscreen) + parallax-tied transition |
| **Story dismiss** | Drag down | `motion.depart` downward, gesture-driven |
| **Splash → Home** | Cold launch boot | `motion.depart` upward of splash + `motion.arrive` of home |

`Hero` (Flutter's shared-element transition) is **not used** in Velix. Two reasons:

1. `Hero` is hard to interrupt cleanly. Mid-flight cancellation produces visual glitches that we can't accept at this quality bar.
2. The element-transitions we want — chat-list-cell to conversation-header, story-thumbnail to story-fullscreen — are achievable via `motion.lateral` + spring-driven sub-element layout without Hero's overhead.

## `VelixPageRoute`

A `PageRoute` subclass that owns push/pop, gesture-driven swipe-back, and the integration with the floating navigation visibility.

### Animation

- Forward push: incoming page slides in from the right (LTR) at the controller's progress; outgoing page slides 0.3× the same distance in the opposite direction (parallax). Opacity dips to 0.6 on the outgoing.
- Pop: reverse.
- Spring: `motion.lateral` (stiffness 360, damping 30).
- Duration: 380 ms median; gesture-driven duration scales 200–500 ms based on velocity at release.

### Edge-swipe back

- Honors iOS edge-swipe from the trailing edge for the platform's text direction.
- 1:1 finger tracking during drag.
- Threshold: 50% of screen width or velocity ≥ 1200 px/s.

### Floating-nav coordination

Some routes (`/chat/:id`, `/stories`, `/voice-message`, `/video-call`, `/ai-assistant`) hide the nav. When a hide-route pushes onto a show-route, the floating nav animates out via `motion.depart` downward as part of the transition. When popped, it animates back in via `motion.arrive` upward.

The hiding is encoded in the route metadata, not in the page widget — so `VelixPageRoute` knows without asking the page.

### Reduce Motion

200 ms cross-fade. Layout pre/post identical.

### Implementation

```dart
Navigator.of(context).push(VelixPageRoute(
  page: const ConversationScreen(),
  hidesNav: true,
  semanticLabel: 'Conversation with Quinn',
));
```

The route's animation builder uses the spring controller and exposes the progress value to a `VelixLateral` for the page's content.

## Replace transitions (auth → home)

A clean, deliberate moment. Used for:

- Splash → Home (after onboarding complete)
- Login → Home (sign-in)
- Logout → Login

The old root departs upward + fades; the new root arrives from below + fades. Total duration ≤ 480 ms. No back gesture; replacements are one-way.

The new root's first frame is built before the transition starts, so there's no "loading flash" between routes.

## Modal present (Tier-3)

Bound to `VelixModal` (Phase 4 doc 07). Pattern: `motion.arrive` of the modal at Z3, with a scrim cross-fade and an additional 8 px blur applied to the substrate.

The substrate is desaturated to 70% during modal presentation. This is the spatial cue.

### Reduce Transparency

Scrim becomes opaque at 96% rather than blur-and-dim.

## Story open / dismiss

The most interesting transition in the system.

### Open

- Tap story thumbnail in the chat list or feed.
- The thumbnail rises to Z2.5 via `motion.lift`.
- Simultaneously, the lifted thumbnail's bounding rectangle animates to fullscreen via a spring (`motion.arrive`).
- The fullscreen story content cross-fades in inside the rectangle.
- Total duration: ~480 ms.

### Dismiss

- Drag-down on the story.
- Position follows finger 1:1; the story scales 1.00 → 0.92 over the drag.
- Release past 30% downward velocity: complete `motion.depart` to thumbnail position; thumbnail re-settles via `motion.settle` (no extra haptic — the dismiss has its own).
- Release below threshold: spring back to fullscreen with velocity hand-off.

### Implementation

A specialized `VelixStoryRoute` (extends `VelixPageRoute`) holds the thumbnail bounds across the transition for the rectangle animation. The implementation does not use `Hero`; it uses an explicit `RectTween` plus the substrate cross-fade.

### Reduce Motion

200 ms cross-fade between thumbnail-position and fullscreen, no rectangle animation.

## Splash → Home

The cold-launch boot transition.

### Sequence

1. Splash renders (fully built before Flutter's first frame, via native splash on iOS / Android).
2. App boots in background — auth check, key loading, message-store hydration. Target ≤ 600 ms.
3. When ready, splash departs via `motion.depart` upward over 220 ms.
4. Home arrives via `motion.arrive` (no scale, just translation + opacity) from below over 320 ms.

The splash's gradient fades during step 3 so the transition is gradient-to-substrate, not a hard cut. Total perceived "boot" time: ≤ 800 ms target.

If the boot exceeds 800 ms, the splash holds with no spinner (we don't show a spinner that might disappear in 50 ms). The user sees a splash that never gets ugly.

## What's banned

- `Hero` widget (see top of doc).
- Custom transitions invented per route. The eight types above are the entire vocabulary.
- Different transition speeds per surface ("modals are slower" / "settings transitions are faster"). We use the system constants.
- Cross-fades between unrelated surfaces.
- Animations that pause briefly at midpoint.
- "Genie" or "morph" effects between rectangles of different aspect ratios.
- Curtains, shutters, page-flips, page-curls.
- Slide-up that bounces.

## Frame stability targets

For each transition type, on iPhone 12 and Pixel 6:

| Transition | 99th percentile frame time |
|---|---|
| Push | ≤ 16.6 ms |
| Pop (gesture-driven) | ≤ 16.6 ms |
| Modal present | ≤ 16.6 ms |
| Story open | ≤ 16.6 ms |
| Splash → Home | ≤ 16.6 ms |
| Replace | ≤ 16.6 ms |

Verified by CI bench. A regression > 5% blocks merge.
