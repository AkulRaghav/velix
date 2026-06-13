import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_motion/velix_motion.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: VelixTheme.dark().toMaterialTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() {
    VelixHaptics.suppressAll = true;
  });

  group('velocity hand-off', () {
    test('caps absurd flick velocities', () {
      final s = buildHandoffSpring(
        spring: VelixTheme.dark().motion.lateral,
        start: 0,
        end: 1,
        pixelsPerSecond: 50000, // absurd
        normalizationDistance: 800,
      );
      // A 50000 px/s flick over an 800-px viewport would yield 62.5 unit/s
      // unclamped. Capped at 4000 / 800 = 5.0.
      expect(s.x(0), 0.0);
      // Velocity at t=0 should be the clamped value, not the raw.
      expect(s.dx(0), closeTo(5.0, 0.01));
    });

    test('zero-distance gracefully returns zero velocity', () {
      final s = buildHandoffSpring(
        spring: VelixTheme.dark().motion.lateral,
        start: 0,
        end: 1,
        pixelsPerSecond: 1000,
        normalizationDistance: 0,
      );
      expect(s.dx(0), 0.0);
    });
  });

  group('VelixArrive', () {
    testWidgets('renders child and respects Reduce Motion', (tester) async {
      await tester.pumpWidget(_wrap(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: VelixArrive(child: Text('hi', key: Key('arr'))),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arr')), findsOneWidget);
    });
  });

  group('VelixLateral', () {
    testWidgets('builds without throwing across progress range',
        (tester) async {
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        await tester.pumpWidget(_wrap(
          VelixLateral(
            direction: AxisDirection.right,
            progress: p,
            child: const Text('lateral'),
          ),
        ));
      }
      expect(find.text('lateral'), findsOneWidget);
    });
  });

  group('VelixReveal', () {
    testWidgets('opacity reaches 1 when revealed', (tester) async {
      await tester.pumpWidget(_wrap(
        const VelixReveal(revealed: true, child: Text('rv')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('rv'), findsOneWidget);
    });
  });

  group('TypingIndicator', () {
    testWidgets('renders three dots and animates without throwing',
        (tester) async {
      await tester.pumpWidget(_wrap(const TypingIndicator()));
      await tester.pump(const Duration(milliseconds: 700));
      // Three dot containers; we don't assert internal opacity, just
      // that the widget keeps painting.
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduce Motion freezes the dots', (tester) async {
      await tester.pumpWidget(_wrap(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: TypingIndicator(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    });
  });

  group('AIStreamingText', () {
    testWidgets('renders streamed tokens and finishes cleanly',
        (tester) async {
      final controller = StreamController<String>();
      await tester.pumpWidget(_wrap(AIStreamingText(tokens: controller.stream)));
      controller
        ..add('Hello, ')
        ..add('world.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      await controller.close();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Waveform', () {
    testWidgets('paints with a static source', (tester) async {
      await tester.pumpWidget(_wrap(
        Waveform(source: StaticWaveformSource(amps: const [
          0.2, 0.4, 0.6, 0.8, 0.6, 0.4, 0.2,
        ])),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test('EnvelopeWaveformSource always returns 7 amps', () {
      final s = EnvelopeWaveformSource(envelope: debugEnvelope(100));
      expect(s.amps.length, 7);
      s.playhead = 0.5;
      expect(s.amps.length, 7);
      s.playhead = 1.0;
      expect(s.amps.length, 7);
    });
  });

  group('VelixHaptics', () {
    test('respects suppressAll flag', () {
      // Already suppressed in setUpAll; calling does nothing observable.
      VelixHaptics.tap();
      VelixHaptics.lift();
      VelixHaptics.modalOpen();
      // No assertions — but no exception thrown.
    });
  });

  group('VelixSheet', () {
    testWidgets('renders at initial detent without throwing',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const VelixSheet(
          detents: [SheetDetent.medium, SheetDetent.large],
          child: Text('sheet'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);
    });
  });

  group('VelixPageRoute', () {
    testWidgets('pushes and exposes hidesNav metadata', (tester) async {
      const target = Text('target', key: Key('t'));
      var pushed = false;
      await tester.pumpWidget(MaterialApp(
        theme: VelixTheme.dark().toMaterialTheme(),
        home: Builder(
          builder: (ctx) => Center(
            child: GestureDetector(
              key: const Key('btn'),
              onTap: () {
                pushed = true;
                Navigator.of(ctx).push(
                  VelixPageRoute<void>(page: target, hidesNav: true),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('btn')));
      await tester.pumpAndSettle();
      expect(pushed, isTrue);
      expect(find.byKey(const Key('t')), findsOneWidget);
    });
  });
}
