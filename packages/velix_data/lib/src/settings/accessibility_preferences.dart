import 'dart:convert';
import 'dart:io';

/// User-configurable accessibility preferences.
///
/// Backs the Accessibility settings screen (launch-readiness D4). Values are
/// persisted as JSON on disk via [AccessibilityPreferencesStore], mirroring
/// the alpha session-store pattern (no secure-storage dependency required —
/// these are non-sensitive UI preferences).
///
/// Gesture thresholds are expressed as multipliers applied to the design
/// system's base thresholds, so a value of 1.0 means "system default". The
/// allowed range is clamped to keep the UI usable.
class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.reduceMotion = false,
    this.reduceTransparency = false,
    this.highContrast = false,
    this.longPressMultiplier = 1.0,
    this.swipeMultiplier = 1.0,
    this.captionsEnabled = false,
  });

  /// Force reduced motion regardless of the OS-level setting.
  final bool reduceMotion;

  /// Force opaque surfaces (disable glass blur) regardless of OS setting.
  final bool reduceTransparency;

  /// Request higher-contrast text and borders.
  final bool highContrast;

  /// Multiplier on the long-press dwell threshold. 1.0 == default (320 ms).
  /// Higher = longer dwell required; lower = quicker activation.
  final double longPressMultiplier;

  /// Multiplier on swipe/flick distance + velocity thresholds. 1.0 == default.
  /// Higher = more deliberate swipe required.
  final double swipeMultiplier;

  /// Show captions for voice/video media where available.
  final bool captionsEnabled;

  /// The smallest accepted multiplier. Below this, gestures become too easy
  /// to trigger accidentally.
  static const double minMultiplier = 0.5;

  /// The largest accepted multiplier. Above this, gestures become unreachable
  /// for some motor profiles.
  static const double maxMultiplier = 2.5;

  static double clampMultiplier(double v) {
    if (v < minMultiplier) return minMultiplier;
    if (v > maxMultiplier) return maxMultiplier;
    return v;
  }

  AccessibilityPreferences copyWith({
    bool? reduceMotion,
    bool? reduceTransparency,
    bool? highContrast,
    double? longPressMultiplier,
    double? swipeMultiplier,
    bool? captionsEnabled,
  }) {
    return AccessibilityPreferences(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      highContrast: highContrast ?? this.highContrast,
      longPressMultiplier:
          clampMultiplier(longPressMultiplier ?? this.longPressMultiplier),
      swipeMultiplier:
          clampMultiplier(swipeMultiplier ?? this.swipeMultiplier),
      captionsEnabled: captionsEnabled ?? this.captionsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'reduce_motion': reduceMotion,
        'reduce_transparency': reduceTransparency,
        'high_contrast': highContrast,
        'long_press_multiplier': longPressMultiplier,
        'swipe_multiplier': swipeMultiplier,
        'captions_enabled': captionsEnabled,
      };

  factory AccessibilityPreferences.fromJson(Map<String, dynamic> j) {
    double readMul(String key) {
      final v = j[key];
      if (v is num) return clampMultiplier(v.toDouble());
      return 1.0;
    }

    bool readBool(String key) => j[key] == true;

    return AccessibilityPreferences(
      reduceMotion: readBool('reduce_motion'),
      reduceTransparency: readBool('reduce_transparency'),
      highContrast: readBool('high_contrast'),
      longPressMultiplier: readMul('long_press_multiplier'),
      swipeMultiplier: readMul('swipe_multiplier'),
      captionsEnabled: readBool('captions_enabled'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccessibilityPreferences &&
      other.reduceMotion == reduceMotion &&
      other.reduceTransparency == reduceTransparency &&
      other.highContrast == highContrast &&
      other.longPressMultiplier == longPressMultiplier &&
      other.swipeMultiplier == swipeMultiplier &&
      other.captionsEnabled == captionsEnabled;

  @override
  int get hashCode => Object.hash(
        reduceMotion,
        reduceTransparency,
        highContrast,
        longPressMultiplier,
        swipeMultiplier,
        captionsEnabled,
      );
}

/// Reads / writes [AccessibilityPreferences] from a JSON file.
class AccessibilityPreferencesStore {
  AccessibilityPreferencesStore({required this.path});
  final String path;

  Future<AccessibilityPreferences> load() async {
    final f = File(path);
    if (!await f.exists()) return const AccessibilityPreferences();
    final raw = await f.readAsString();
    if (raw.isEmpty) return const AccessibilityPreferences();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AccessibilityPreferences.fromJson(json);
    } catch (_) {
      return const AccessibilityPreferences();
    }
  }

  Future<void> save(AccessibilityPreferences prefs) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(prefs.toJson()));
  }
}
