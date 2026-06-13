import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:velix_app/src/di/providers.dart';
import 'package:velix_data/velix_data.dart';

String _tmpPath(String tag) {
  final dir = Directory.systemTemp.path;
  return '$dir${Platform.pathSeparator}velix-a11y-$tag-${DateTime.now().microsecondsSinceEpoch}.json';
}

void main() {
  test('controller persists each preference change through the store',
      () async {
    final store = AccessibilityPreferencesStore(path: _tmpPath('ctrl'));
    final controller = AccessibilityPreferencesController(
      store: store,
      initial: const AccessibilityPreferences(),
    );

    await controller.setReduceMotion(true);
    expect((await store.load()).reduceMotion, isTrue);

    await controller.setHighContrast(true);
    expect((await store.load()).highContrast, isTrue);

    await controller.setLongPressMultiplier(2.0);
    expect((await store.load()).longPressMultiplier, 2.0);

    // Out-of-range values are clamped before persistence.
    await controller.setSwipeMultiplier(99.0);
    expect((await store.load()).swipeMultiplier,
        AccessibilityPreferences.maxMultiplier,);

    await controller.setCaptionsEnabled(true);
    expect((await store.load()).captionsEnabled, isTrue);

    controller.dispose();
  });
}
