import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velix_3d/velix_3d.dart';
import 'package:velix_design/velix_design.dart';

void main() {
  group('SceneId', () {
    test('locked scope is exactly five entries', () {
      expect(SceneId.values.length, 5);
      expect(SceneId.values, containsAll([
        SceneId.onboardingStep1,
        SceneId.onboardingStep2,
        SceneId.onboardingStep3,
        SceneId.profileIdentity,
        SceneId.spaceAmbient,
      ]));
    });

    test('category extensions are correct', () {
      expect(SceneId.onboardingStep1.isOnboarding, isTrue);
      expect(SceneId.profileIdentity.isPersistent, isTrue);
      expect(SceneId.spaceAmbient.isPersistent, isTrue);
      expect(SceneId.profileIdentity.isOnboarding, isFalse);
    });
  });

  group('SceneParams', () {
    test('defaults to quartz with calm drift and responsive parallax', () {
      const p = SceneParams();
      expect(p.style, SceneStyle.quartz);
      expect(p.driftPace, DriftPace.calm);
      expect(p.parallaxIntensity, ParallaxIntensity.responsive);
    });

    test('drift pace maps to expected periods', () {
      expect(DriftPace.calm.period, const Duration(seconds: 32));
      expect(DriftPace.alert.period, const Duration(seconds: 18));
    });

    test('parallax tilt factors match the scene spec', () {
      expect(ParallaxIntensity.still.tiltFactor, 0.05);
      expect(ParallaxIntensity.responsive.tiltFactor, 0.18);
    });

    test('SceneStyle hash mapping is deterministic', () {
      expect(
        SceneStyleHashing.fromHash(123),
        SceneStyleHashing.fromHash(123),
      );
      // Eight styles, modular wrap.
      expect(
        SceneStyleHashing.fromHash(0),
        SceneStyleHashing.fromHash(8),
      );
    });
  });

  group('NoopSceneController', () {
    test('starts notLoaded and remains unhealthy through load', () async {
      final c = NoopSceneController();
      expect(c.lifecycle.value, SceneLifecycle.notLoaded);
      expect(c.healthy.value, isFalse);

      await c.load(SceneId.profileIdentity);
      // The noop controller never reports healthy: hosting widgets stay on fallback.
      expect(c.healthy.value, isFalse);
      expect(c.lifecycle.value, SceneLifecycle.paused);

      await c.dispose();
      expect(c.lifecycle.value, SceneLifecycle.disposed);
    });

    test('startPaused suppresses transition to rendering on resume', () async {
      final c = NoopSceneController();
      await c.load(SceneId.profileIdentity, startPaused: true);
      c.resume();
      expect(c.lifecycle.value, SceneLifecycle.paused);
      await c.dispose();
    });
  });

  group('SceneMetrics.healthy', () {
    test('returns true only inside budgets', () {
      const good = SceneMetrics(
        gpuFrameMs: 2.5,
        cpuFrameMs: 1.0,
        frameStability99: 0.995,
        droppedFramesLastSecond: 0,
      );
      expect(good.healthy, isTrue);

      const overGpu = SceneMetrics(
        gpuFrameMs: 5.0,
        cpuFrameMs: 1.0,
        frameStability99: 0.995,
        droppedFramesLastSecond: 0,
      );
      expect(overGpu.healthy, isFalse);

      const tooManyDrops = SceneMetrics(
        gpuFrameMs: 2.5,
        cpuFrameMs: 1.0,
        frameStability99: 0.99,
        droppedFramesLastSecond: 5,
      );
      expect(tooManyDrops.healthy, isFalse);
    });
  });

  group('VelixSceneWidget', () {
    testWidgets('shows fallback when 3D is not healthy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VelixTheme.dark().toMaterialTheme(),
          home: const Scaffold(
            body: VelixSceneWidget(
              scene: SceneId.profileIdentity,
              fallback: Text('FALLBACK', key: Key('fb')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fb')), findsOneWidget);
    });

    testWidgets('routes to fallback when Reduce Transparency is on',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VelixTheme.dark().toMaterialTheme(),
          home: const MediaQuery(
            data: MediaQueryData(highContrast: true),
            child: Scaffold(
              body: VelixSceneWidget(
                scene: SceneId.profileIdentity,
                fallback: Text('FALLBACK', key: Key('fb')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fb')), findsOneWidget);
    });
  });
}
