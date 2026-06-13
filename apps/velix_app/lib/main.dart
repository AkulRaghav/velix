import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/bootstrap/bootstrap.dart';
import 'src/di/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 9 F5 — bound image cache. Defaults are too generous for a
  // messaging app where images are decrypted on-device and held in RAM.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;

  await runZonedGuarded(
    () async {
      final boot = await Bootstrap.run();
      runApp(
        ProviderScope(
          overrides: [bootstrapProvider.overrideWithValue(boot)],
          child: const VelixApp(),
        ),
      );
    },
    (error, stackTrace) {
      // Phase 5: console only. Phase 7+ routes this through velix_telemetry
      // with PII scrubbing and remote sink.
      // ignore: avoid_print
      print('uncaught: $error\n$stackTrace');
    },
  );
}
