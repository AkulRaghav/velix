import 'dart:io';

import 'package:test/test.dart';
import 'package:velix_data/velix_data.dart';

void main() {
  group('AccessibilityPreferences', () {
    test('defaults are system-neutral', () {
      const p = AccessibilityPreferences();
      expect(p.reduceMotion, isFalse);
      expect(p.reduceTransparency, isFalse);
      expect(p.highContrast, isFalse);
      expect(p.longPressMultiplier, 1.0);
      expect(p.swipeMultiplier, 1.0);
      expect(p.captionsEnabled, isFalse);
    });

    test('copyWith clamps multipliers to the allowed range', () {
      const p = AccessibilityPreferences();
      expect(p.copyWith(longPressMultiplier: 99.0).longPressMultiplier,
          AccessibilityPreferences.maxMultiplier);
      expect(p.copyWith(swipeMultiplier: 0.01).swipeMultiplier,
          AccessibilityPreferences.minMultiplier);
    });

    test('json round-trips', () {
      const p = AccessibilityPreferences(
        reduceMotion: true,
        highContrast: true,
        longPressMultiplier: 1.5,
        swipeMultiplier: 0.75,
        captionsEnabled: true,
      );
      final back = AccessibilityPreferences.fromJson(p.toJson());
      expect(back, p);
    });

    test('fromJson clamps out-of-range and tolerates missing keys', () {
      final p = AccessibilityPreferences.fromJson({
        'long_press_multiplier': 10.0,
        'swipe_multiplier': -1.0,
      });
      expect(p.longPressMultiplier, AccessibilityPreferences.maxMultiplier);
      expect(p.swipeMultiplier, AccessibilityPreferences.minMultiplier);
      expect(p.reduceMotion, isFalse);
    });

    test('fromJson tolerates malformed values', () {
      final p = AccessibilityPreferences.fromJson({
        'long_press_multiplier': 'not-a-number',
        'reduce_motion': 'yes',
      });
      expect(p.longPressMultiplier, 1.0);
      // Only literal `true` enables a flag.
      expect(p.reduceMotion, isFalse);
    });
  });

  group('AccessibilityPreferencesStore', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('velix_a11y_test');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('load returns defaults when file is absent', () async {
      final store = AccessibilityPreferencesStore(
        path: '${tmp.path}/missing.json',
      );
      expect(await store.load(), const AccessibilityPreferences());
    });

    test('save then load round-trips through disk', () async {
      final store = AccessibilityPreferencesStore(
        path: '${tmp.path}/prefs.json',
      );
      const prefs = AccessibilityPreferences(
        reduceMotion: true,
        longPressMultiplier: 2.0,
        captionsEnabled: true,
      );
      await store.save(prefs);
      expect(await store.load(), prefs);
    });

    test('load returns defaults on corrupt file', () async {
      final path = '${tmp.path}/corrupt.json';
      await File(path).writeAsString('{not valid json');
      final store = AccessibilityPreferencesStore(path: path);
      expect(await store.load(), const AccessibilityPreferences());
    });
  });
}
