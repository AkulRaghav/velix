# 08 — Scroll Behavior

Scroll is where every app's "feel" lives. Most products use the platform default and call it done. Velix tunes scroll explicitly to match Apple's character on every platform.

## `VelixScrollPhysics`

A `ScrollPhysics` subclass overriding the Flutter defaults to produce iOS-style behavior on every platform — bouncy edges, momentum that feels right, deceleration that matches the eye.

### Constants

We base on `BouncingScrollPhysics` (iOS) and tune:

| Parameter | Value | Default | Justification |
|---|---|---|---|
| `dragStartDistanceMotionThreshold` | 3.5 | 3.5 | Apple default; small motion before scroll begins |
| Friction (deceleration) | 0.135 | 0.135 (iOS) / 0.50 (Android) | Apple's iOS feel everywhere; Android default decelerates too quickly |
| Bounciness past edge | 0.5 (rubber-band coefficient) | 0.5 (iOS) | Same |
| Maximum fling velocity | 8000 px/s | unbounded | Cap absurd flicks |
| Spring back (`spring` description) | mass=1, stiffness=200, damping=20 | iOS uses ~similar | Critically damped, no overshoot at edge |

These are tuned by reference video against iOS 17 Mail's chat-list scroll. We use the exact same friction whether the app runs on iOS, Android, macOS, Windows, or Linux.

Why not match Android's default on Android? Because Velix's brand voice is consistent everywhere, and Android's default (steep deceleration) makes a large list feel "stuck" compared to the iOS feel. We own the scroll feel.

### Per-platform haptics

When the user scrolls past the top or bottom of a `ScrollView` and the rubber-band engages, no haptic. (iOS has none, and adding one feels wrong.) We do not invent platform-specific scroll haptics.

## Pull-to-refresh

Spec'd in `05-gestures.md`; here we focus on the scroll-physics interaction.

The pull-to-refresh affordance uses an over-scroll region attached to the top of the list. As the user pulls past 0, the over-scroll slows to 0.5× and the affordance grows from 0 to its full size at offset 80–120 px.

Behavior:
- Spring back when released below threshold uses the same `spring back` parameters above.
- When the threshold is crossed, `VelixHaptics.pullToRefreshThreshold` (light) fires once.
- When the user releases past threshold, the affordance triggers refresh and locks at `120 px` overscroll until the refresh completes; then springs back smoothly.

## Scroll deceleration during programmatic insertion

When new messages arrive at the top of a chat list while the user is reading, we do **not** auto-scroll to the new message. The user owns scroll position. Instead:

- The list inserts the new message off-screen above.
- The scroll position is preserved — Flutter's `keepScrollOffset` is on.
- A subtle "↑ {n} new" affordance appears at the top, tap to scroll up.

This is the iMessage / Discord pattern. Auto-scroll-to-bottom on incoming-message is for chat-bubble lists, not chat-list-of-conversations.

## Scroll-driven parallax

`VelixParallax` reads the scroll offset and translates layers at fractional rates. Implemented via `NotificationListener<ScrollUpdateNotification>` to avoid coupling the parallax widget to the scroll view's controller.

Key rule: **parallax never causes the scroll to feel different**. The parallax layer renders independently; the actual scrolling content is unaffected. If a parallax background has heavy paint cost, we reduce *its* update rate to 30 fps via a debounce, not the scroll's.

## Animations during scroll

Banned. Documented in `00-system-overview.md`. Implementation:

- `VelixArrive` and friends pause when their `ScrollController` reports `position.isScrollingNotifier == true`.
- They resume on scroll-end and animate to the next state.
- Lists with many `VelixArrive` children (e.g., chat list initial paint) use a single batched arrival rather than per-cell animation, with stagger ≤ 8 visible cells.

## Scroll-driven app-bar collapse

We do not have a collapsing app-bar. The chat-list header is a fixed Tier-2 active material at the top of the screen; it does not shrink, fade, or transform on scroll. (Tested patterns like Material's `SliverAppBar` are too noisy for our brand voice.)

## Inertial scrolling end behavior

When a scroll's inertia carries it to its end (reaches offset 0 or maxScrollExtent), the rubber-band springs back. Default Apple behavior. No extra effects.

## Scroll-coupled element transitions

A few surfaces use scroll position to drive layout transitions:

- **Profile hero** — the spatial scene at top fades into the substrate as the user scrolls down past 200 px. Implemented as a fade based on `scrollOffset / 200` clamped to [0, 1].
- **Conversation header** — the trust-state shield's text label fades out as the user scrolls; the glyph stays. Same clamp pattern.

These are *not* parallax in the strict sense — they are parameter bindings tied to scroll. The motion is pure linear (the input is linear gesture position).

## Per-platform considerations

| Platform | Notes |
|---|---|
| iOS | Native scroll behavior matches Velix's tuning closely. No additional work. |
| Android | Override `ScrollPhysics` to use `BouncingScrollPhysics` everywhere. Disables the Android over-scroll glow. |
| macOS / Windows / Linux | Mouse wheel is mapped through `Scrollable`; we honor accumulated wheel delta and produce smooth scroll. Touchpad scroll uses platform velocity. |
| Web | iOS physics emulated. Performance acceptable on Chromium and Firefox. |

## Scroll performance contract

For a chat list with 50 visible cells, on iPhone 12 and Pixel 6:

| Metric | Target |
|---|---|
| 99th-percentile frame time during fling | ≤ 16.6 ms |
| Mean frame time during fling | ≤ 8 ms |
| Memory growth across 30 seconds of fling | ≤ 8 MB |

Audited via CI bench on physical-device cloud (BrowserStack or equivalent).

## Banned

- "Scroll-jacking" — overriding the scroll position to scrub a video or animation. Banned.
- Auto-scroll on data update (except the explicit single case where the user is at the bottom of a chat-bubble view and a new bubble arrives — that's the chat-bubble-list rule, not chat-list).
- Custom over-scroll bounce coefficients per surface.
- "Sticky headers" with parallax tilt within a scroll. Use the Z-tier system; sticky headers are Tier-1 and don't move.
- Scroll-driven 3D camera-movement. (We use the 3D system's scroll-factor, but those are 2D parallax of 3D layers, not camera movement.)
