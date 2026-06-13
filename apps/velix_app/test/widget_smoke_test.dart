import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velix_app/src/bootstrap/bootstrap.dart';
import 'package:velix_app/src/di/providers.dart';
import 'package:velix_app/src/presentation/components/glass_card.dart';
import 'package:velix_app/src/presentation/components/identity_capsule.dart';
import 'package:velix_app/src/presentation/components/velix_button.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_domain/velix_domain.dart';
import 'package:velix_motion/velix_motion.dart';

String _missingSessionPath() {
  // OS-agnostic path that does not exist; Bootstrap.run treats missing file
  // as "first run".
  final dir = Directory.systemTemp.path;
  return '$dir${Platform.pathSeparator}velix-no-such-file-${DateTime.now().microsecondsSinceEpoch}.json';
}

Widget _wrap(Widget child) {
  // Use VelixThemeProvider directly so the extension is guaranteed to be on
  // the Theme widget that wraps `child`. (MaterialApp's internal theme copy
  // can drop extensions in some Flutter SDKs; this avoids the problem in
  // tests.)
  return MaterialApp(
    home: Scaffold(
      body: VelixThemeProvider(
        theme: VelixTheme.dark(),
        child: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    VelixHaptics.suppressAll = true;
  });

  group('Bootstrap', () {
    test('first-run produces non-null identity and empty conversations',
        () async {
      final boot =
          await Bootstrap.run(sessionPath: _missingSessionPath());
      final list = await boot.conversationRepository.watchAll().first;
      expect(list, isEmpty);
      final id = await boot.identityRepository.watch().first;
      expect(id, isNotNull);
    });
  });

  group('Components (single-frame smoke)', () {
    // We deliberately do NOT pumpAndSettle: VelixButton's loader and
    // VelixArrive in MessageBubble run infinite animations that never
    // settle in the test harness. tester.pump() renders one frame, which
    // is enough to assert presence of the widget tree.

    testWidgets('VelixButton renders and is tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          Center(
            child: VelixButton(label: 'Send', onPressed: () => taps++),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Send'), findsOneWidget);
      await tester.tap(find.text('Send'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(taps, 1);
    });

    testWidgets('GlassCard renders quiet and active tiers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              GlassCard(child: Text('A')),
              GlassCard(tier: GlassCardTier.active, child: Text('B')),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('IdentityCapsule renders the title initial', (tester) async {
      await tester.pumpWidget(
        _wrap(const Center(child: IdentityCapsule(title: 'Quinn'))),
      );
      await tester.pump();
      expect(find.text('Q'), findsOneWidget);
    });
  });

  group('App boot smoke', () {
    test('chats provider streams an empty list on first run', () async {
      final boot =
          await Bootstrap.run(sessionPath: _missingSessionPath());
      final container = ProviderContainer(
        overrides: [bootstrapProvider.overrideWithValue(boot)],
      );
      addTearDown(container.dispose);
      final cs = await container
          .read(conversationRepositoryProvider)
          .watchAll()
          .first;
      expect(cs, isA<List<Conversation>>());
    });
  });
}
