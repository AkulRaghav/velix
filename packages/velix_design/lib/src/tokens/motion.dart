import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Velix motion grammar.
///
/// Seven patterns. Spring physics or carefully tuned cubic-beziers.
/// Reduce-Motion collapses everything to a 120 ms cross-fade.
class VelixMotion {
  const VelixMotion();

  // Spring descriptions used by SpringSimulation.
  SpringDescription get arrive => const SpringDescription(
        mass: 1, stiffness: 400, damping: 32,
      );

  SpringDescription get lateral => const SpringDescription(
        mass: 1, stiffness: 360, damping: 30,
      );

  SpringDescription get lift => const SpringDescription(
        mass: 1, stiffness: 500, damping: 28,
      );

  SpringDescription get settle => const SpringDescription(
        mass: 1, stiffness: 320, damping: 36,
      );

  // Curves used by Tween-driven animations.
  Curve get depart => const Cubic(0.4, 0.0, 1.0, 0.5);
  Curve get reveal => const Cubic(0.2, 0.0, 0.0, 1.0);
  Curve get parallax => Curves.linear; // gesture-driven, by definition

  // Median durations. Gesture-driven motion overrides these with velocity.
  Duration get durationArrive => const Duration(milliseconds: 320);
  Duration get durationDepart => const Duration(milliseconds: 220);
  Duration get durationLateral => const Duration(milliseconds: 380);
  Duration get durationLift => const Duration(milliseconds: 240);
  Duration get durationSettle => const Duration(milliseconds: 280);
  Duration get durationReveal => const Duration(milliseconds: 240);
  Duration get reduceMotionFallback => const Duration(milliseconds: 120);

  /// Tap micro-press: 0.97 scale, brief.
  Duration get tapMicroPress => const Duration(milliseconds: 220);

  /// First-time-arrival reveal (e.g., room color materialization).
  /// Used precisely once per qualifying event; not a default.
  Duration get cinematicReveal => const Duration(milliseconds: 600);
}
