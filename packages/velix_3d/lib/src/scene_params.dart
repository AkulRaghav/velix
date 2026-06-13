import 'package:flutter/painting.dart';

/// Per-scene parameters. Personalization is local-only and never travels
/// to the server. See `docs/phase-3/04-profile-identity-scene.md`.
class SceneParams {
  const SceneParams({
    this.style = SceneStyle.quartz,
    this.tint,
    this.driftPace = DriftPace.calm,
    this.parallaxIntensity = ParallaxIntensity.responsive,
  });

  /// Style template — one of eight. Default is `quartz`, matching the locked
  /// signature accent.
  final SceneStyle style;

  /// Optional tint color. When null, derived from the user's room palette
  /// or defaults to the signature accent tint.
  final Color? tint;

  final DriftPace driftPace;
  final ParallaxIntensity parallaxIntensity;

  SceneParams copyWith({
    SceneStyle? style,
    Color? tint,
    DriftPace? driftPace,
    ParallaxIntensity? parallaxIntensity,
  }) {
    return SceneParams(
      style: style ?? this.style,
      tint: tint ?? this.tint,
      driftPace: driftPace ?? this.driftPace,
      parallaxIntensity: parallaxIntensity ?? this.parallaxIntensity,
    );
  }
}

/// The eight identity / space styles. Reused between profile and space
/// backdrop for visual coherence and shared asset cost.
enum SceneStyle {
  quartz,
  aurora,
  forest,
  mist,
  coral,
  iris,
  slate,
  pacific,
}

extension SceneStyleHashing on SceneStyle {
  /// Auto-derive a style from any account hash. Deterministic across users.
  static SceneStyle fromHash(int hash) =>
      SceneStyle.values[hash.abs() % SceneStyle.values.length];
}

enum DriftPace {
  calm, // 32 s period
  alert, // 18 s period
}

enum ParallaxIntensity {
  still, // tilt-factor 0.05
  responsive, // tilt-factor 0.18
}

extension DriftPaceMs on DriftPace {
  Duration get period => switch (this) {
        DriftPace.calm => const Duration(seconds: 32),
        DriftPace.alert => const Duration(seconds: 18),
      };
}

extension ParallaxFactor on ParallaxIntensity {
  double get tiltFactor => switch (this) {
        ParallaxIntensity.still => 0.05,
        ParallaxIntensity.responsive => 0.18,
      };
}
