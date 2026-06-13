import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:velix_design/velix_design.dart';

void main() {
  group('VelixTheme', () {
    test('locked Brand.quartzBlue produces signature accent #3478F6', () {
      final t = VelixTheme.dark();
      expect(t.brand, Brand.quartzBlue);
      expect(t.colors.accent.signature.value, 0xFF3478F6);
      expect(t.colors.accent.s10.value, 0xFF0F3A8E);
      expect(t.colors.accent.s50.value, 0xFFD4E0FF);
    });

    test('toMaterialTheme bakes the VelixTheme extension into ThemeData', () {
      final t = VelixTheme.dark();
      final mat = t.toMaterialTheme();
      // Round-trip: extracting the extension should yield the same instance.
      expect(mat.extension<VelixTheme>(), same(t));
    });

    testWidgets('MaterialApp with toMaterialTheme exposes context.velix',
        (tester) async {
      final theme = VelixTheme.dark();
      late VelixTheme captured;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme.toMaterialTheme(),
          home: Builder(
            builder: (ctx) {
              captured = ctx.velix;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(captured.brand, Brand.quartzBlue);
      expect(captured.colors.surface.substrate.value, 0xFF08090C);
    });

    testWidgets('VelixThemeProvider works for non-MaterialApp roots',
        (tester) async {
      final theme = VelixTheme.dark();
      late VelixTheme captured;

      await tester.pumpWidget(
        VelixThemeProvider(
          theme: theme,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (ctx) {
                captured = ctx.velix;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(captured.brand, Brand.quartzBlue);
    });

    test('material tier saturation is monotonic', () {
      final t = VelixTheme.dark();
      expect(t.materials.substrate.saturation,
          lessThanOrEqualTo(t.materials.quiet.saturation));
      expect(t.materials.quiet.saturation,
          lessThanOrEqualTo(t.materials.active.saturation));
      expect(t.materials.active.saturation,
          lessThanOrEqualTo(t.materials.lifted.saturation));
    });

    test('material tier blur is monotonic', () {
      final t = VelixTheme.dark();
      expect(t.materials.substrate.blurSigma,
          lessThanOrEqualTo(t.materials.quiet.blurSigma));
      expect(t.materials.quiet.blurSigma,
          lessThanOrEqualTo(t.materials.active.blurSigma));
      expect(t.materials.active.blurSigma,
          lessThanOrEqualTo(t.materials.lifted.blurSigma));
    });

    test('motion durations are bounded under 500ms', () {
      const m = VelixMotion();
      for (final d in [
        m.durationArrive,
        m.durationDepart,
        m.durationLateral,
        m.durationLift,
        m.durationSettle,
        m.durationReveal,
      ]) {
        expect(d.inMilliseconds, lessThanOrEqualTo(500),
            reason: 'No motion in the grammar exceeds 500 ms.');
      }
      // Cinematic reveal is the deliberate exception.
      expect(m.cinematicReveal.inMilliseconds, lessThanOrEqualTo(700));
    });

    test('room palette has the documented 12 colors', () {
      final t = VelixTheme.dark();
      expect(t.colors.rooms.all.length, 12);
    });

    test('room hash mapping is deterministic and wraps mod 12', () {
      final t = VelixTheme.dark();
      expect(t.colors.rooms.fromHash(123), t.colors.rooms.fromHash(123));
      expect(t.colors.rooms.fromHash(0), t.colors.rooms.fromHash(12));
    });
  });
}
