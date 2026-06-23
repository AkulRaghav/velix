/// Haptic feedback patterns for premium interactions.
import 'package:flutter/services.dart';

class VelixHapticPatterns {
  VelixHapticPatterns._();

  /// Light tap — button press, toggle.
  static void tap() => HapticFeedback.lightImpact();

  /// Medium — successful action, send message.
  static void success() => HapticFeedback.mediumImpact();

  /// Heavy — error, destructive action.
  static void error() => HapticFeedback.heavyImpact();

  /// Selection tick — scrolling through options.
  static void tick() => HapticFeedback.selectionClick();

  /// Vibrate pattern — notification arrival.
  static void notification() => HapticFeedback.vibrate();
}
