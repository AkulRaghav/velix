import 'package:flutter/services.dart';

/// The single coordinator for haptic feedback.
///
/// Every haptic in Velix flows through here. Direct calls to
/// [HapticFeedback] from leaf widgets are forbidden by lint.
///
/// See `docs/phase-4/09-haptics-coordination.md` for the contract.
class VelixHaptics {
  VelixHaptics._();

  /// Used to dedupe haptics that land within 80 ms of each other.
  static DateTime? _lastFire;
  static const Duration _minInterval = Duration(milliseconds: 80);

  /// Globally suppress haptics — used in tests and verified at runtime
  /// against the platform's "haptic feedback enabled" setting.
  static bool suppressAll = false;

  static bool _check() {
    if (suppressAll) return false;
    final now = DateTime.now();
    if (_lastFire != null && now.difference(_lastFire!) < _minInterval) {
      return false;
    }
    _lastFire = now;
    return true;
  }

  // Press of an interactive element. Subtle; many per session.
  static void tap() {
    if (!_check()) return;
    HapticFeedback.selectionClick();
  }

  // Long-press completion (320 ms threshold cross). Definitive.
  static void lift() {
    if (!_check()) return;
    HapticFeedback.mediumImpact();
  }

  // Sheet snaps to a new detent.
  static void sheetDetent() {
    if (!_check()) return;
    HapticFeedback.lightImpact();
  }

  // Modal arrives at 50% travel.
  static void modalOpen() {
    if (!_check()) return;
    HapticFeedback.mediumImpact();
  }

  // Pull-to-refresh threshold cross.
  static void pullToRefreshThreshold() {
    if (!_check()) return;
    HapticFeedback.lightImpact();
  }

  // Swipe-archive completes.
  static void swipeArchive() {
    if (!_check()) return;
    HapticFeedback.lightImpact();
  }

  // Scrubbing through a discrete set; rate-limited to ≤ 30 / second.
  static void selectionScrub() {
    if (!_check()) return;
    HapticFeedback.selectionClick();
  }

  // Action completed successfully. Used sparingly.
  static void success() {
    if (!_check()) return;
    HapticFeedback.lightImpact();
  }

  // Caution.
  static void warning() {
    if (!_check()) return;
    HapticFeedback.mediumImpact();
  }

  // Action failed (rare in a calm app).
  static void error() {
    if (!_check()) return;
    HapticFeedback.heavyImpact();
  }

  // Call connects.
  static void callConnect() {
    if (!_check()) return;
    HapticFeedback.lightImpact();
  }

  // Call ends.
  static void callEnd() {
    if (!_check()) return;
    HapticFeedback.mediumImpact();
  }
}
