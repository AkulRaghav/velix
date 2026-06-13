# 09 — Haptics Coordination

Haptics are easy to abuse. A leaf widget firing a haptic on every tap creates a buzzing product that users learn to ignore. Velix routes every haptic through a single coordinator with a typed event API. The coordinator owns timing, debouncing, and per-platform mapping.

## Principles

1. **Haptics are coordinated with motion.** A haptic fires at a specific moment of a visible animation (lift's first frame past 50%, sheet detent snap at 50% travel). Never on widget construction, never on data arrival, never as a "you have a new message" cue.
2. **Single coordinator.** No widget calls `HapticFeedback.lightImpact()` directly. All haptic invocations go through `VelixHaptics`. Lint enforces.
3. **Typed events, not arbitrary parameters.** `VelixHaptics.lift()`, `VelixHaptics.sheetDetent()`. The coordinator decides what platform haptic that maps to.
4. **Respect OS settings.** iOS's "System Haptics" toggle, Android's "Touch sounds and vibration" — both honored. When off, every coordinator call is a no-op.
5. **Debounced.** Haptics within 80 ms of a previous one are suppressed. Two events landing on the same frame produce one haptic, not two.
6. **Never a substitute for visual feedback.** A haptic without a visible motion is banned. The user cannot rely on haptics alone (accessibility constraint).

## Event taxonomy

The full set. We do not invent new events ad-hoc.

| Event | When | iOS | Android | Comment |
|---|---|---|---|---|
| `tap` | Press of an interactive element | UISelection | `HapticFeedbackConstants.CONFIRM` | Light; many per session, must be subtle |
| `lift` | Long-press completes (320 ms threshold cross) | UIImpactMedium | `LONG_PRESS` | Definitive; signals "I picked this up" |
| `sheetDetent` | Sheet snaps to a new detent | UIImpactLight | `CONTEXT_CLICK` | One per detent change |
| `modalOpen` | Modal arrives (50% travel) | UIImpactMedium | `CONFIRM` | Signals "you've left the previous surface" |
| `pullToRefreshThreshold` | Threshold cross during pull | UIImpactLight | `CLOCK_TICK` | One-shot; never repeated within the gesture |
| `swipeArchive` | Swipe-archive completes | UIImpactLight | `CONFIRM` | One per archive |
| `selectionScrub` | Scrubbing through a discrete set (e.g., voice scrub bar to a snap point) | UISelection | `CLOCK_TICK` | Frequent; rate-limited to ≤ 30 / second |
| `success` | Action completed successfully (verify-contact, copy-handle) | UINotificationSuccess | `CONFIRM` ×2 | Used sparingly |
| `warning` | Caution (destructive confirm landing) | UINotificationWarning | `REJECT` | One-shot |
| `error` | Action failed (rare; should be rare in a calm app) | UINotificationError | `REJECT` | One-shot |
| `callConnect` | Call connects | UINotificationSuccess | `CONFIRM` | Once per call |
| `callEnd` | Call ends | UIImpactMedium | `CONFIRM` | Once per call |

That is the entire vocabulary. New events go through a design review.

## What does NOT fire haptics

A non-exhaustive list of moments people sometimes try to put haptics on, that we explicitly refuse:

- Toggle on/off (the visual is decisive enough)
- Reaction picker open (the source bubble's lift fires the only haptic; the picker's reveal does not)
- Story advance (mute, dismissive, just visual)
- Conversation push navigation (the touch already had its own tap haptic)
- Message bubble arrival (the user's send had its tap haptic; arrivals are silent)
- Notification arrival (sound / banner is the channel; haptic in-app is overkill)
- Loading completion
- Scroll-end / overscroll bounce
- Trust-state material transitions (they're meant to be felt-not-seen; a haptic would over-emphasize)

## API

```dart
VelixHaptics.tap();
VelixHaptics.lift();
VelixHaptics.sheetDetent();
// etc.
```

All calls are static, no-allocation, and return immediately. The coordinator runs on a dedicated method-channel-backed background invocation pipeline so the UI thread never blocks on haptic dispatch.

## Implementation

```dart
class VelixHaptics {
  static DateTime? _lastFire;
  static const _minInterval = Duration(milliseconds: 80);

  static Future<void> _fire(_Pattern p) async {
    if (!await _enabled()) return;
    final now = DateTime.now();
    if (_lastFire != null && now.difference(_lastFire!) < _minInterval) return;
    _lastFire = now;
    await _platform.fire(p);
  }

  static void tap() => _fire(_Pattern.lightImpact);
  static void lift() => _fire(_Pattern.mediumImpact);
  // ...
}
```

`_enabled()` queries the platform once per session and caches; it can be invalidated when the app receives the platform's audio-route-change notification (a proxy for "settings might have changed").

## OS settings detection

- iOS: `UIDevice.current.userInterfaceIdiom` doesn't expose haptic settings directly. We use the convention from system widgets: try the haptic; if the user has disabled it, the OS no-ops it. We assume the OS is the source of truth.
- Android: `Settings.System.HAPTIC_FEEDBACK_ENABLED` query at app start, cached.

## Per-platform mapping

iOS uses `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, `UISelectionFeedbackGenerator`. We instantiate generators on first use and re-use; `prepare()` is called shortly before fires for low-latency delivery.

Android uses `HapticFeedbackConstants` constants and `View.performHapticFeedback`. Newer Androids (12+) support `VibrationEffect`-based finer control; we use it when available for the "scrub" event (a tighter, shorter pulse than `CLOCK_TICK`).

Web has no haptics. All calls are no-ops on web.
Desktop (macOS, Windows, Linux) has no haptics. All calls are no-ops.

## Latency target

From visual-event-trigger to haptic landing: ≤ 30 ms on iPhone 12 and Pixel 6. This is well below the perceptual threshold of "they feel simultaneous."

iOS's `UIImpactFeedbackGenerator.prepare()` is called proactively before known-imminent events (e.g., the moment a long-press starts at 0 ms, we prepare; the haptic is ready by 320 ms). This is a documented Apple pattern.

## Banned

- Haptics from leaf widgets (lint catches calls to `HapticFeedback.*` outside `velix_motion`).
- Custom haptic patterns invented at the call site.
- Haptics that fire on every list-cell rebuild.
- Haptics for "delight" without a paired visible motion.
- Haptics during scroll.
- Haptics in onboarding (we want calm onboarding; tactile pressure pushes the user emotionally).
- Haptic responses to push notifications (the notification has its own platform haptic; we don't add ours).
- Haptics when the user taps a banned-action element with disabled state (silence is better than a "no" haptic).

## Accessibility

Haptics are *additive*, never sole-channel. Every haptic event has an associated visual cue and (where appropriate) an AT announcement. Users who disable haptics or system vibration lose nothing semantically.

## Audit

Every haptic call site is documented in a single registry file (`packages/velix_motion/lib/src/haptics_registry.dart`). The registry maps trigger → event-type → expected visual partner. CI verifies the registry is exhaustive (no `_fire` calls outside the registry's listed sites).
