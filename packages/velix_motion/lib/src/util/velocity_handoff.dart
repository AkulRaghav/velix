import 'package:flutter/physics.dart';

/// Builds a [SpringSimulation] that transfers a gesture's release velocity
/// into spring-driven motion. The most important Apple-grade mechanic in
/// the system.
///
/// - [pixelsPerSecond] is the gesture's release velocity (e.g., from a
///   `VelocityTracker.getVelocity().pixelsPerSecond`).
/// - [normalizationDistance] is the distance over which the simulation runs
///   (e.g., the screen height for a sheet dismiss).
/// - [start] and [end] are unit-space positions for the simulation.
/// - [spring] is the [SpringDescription] from `theme.motion.*`.
///
/// Velocity is capped at [maxPixelsPerSecond] (default 4000 px/s) to prevent
/// over-driven springs that read as glitches.
SpringSimulation buildHandoffSpring({
  required SpringDescription spring,
  required double start,
  required double end,
  required double pixelsPerSecond,
  required double normalizationDistance,
  double maxPixelsPerSecond = 4000,
}) {
  final clamped = pixelsPerSecond.clamp(
    -maxPixelsPerSecond,
    maxPixelsPerSecond,
  );
  final unitVelocity = normalizationDistance == 0
      ? 0.0
      : clamped / normalizationDistance;
  return SpringSimulation(spring, start, end, unitVelocity);
}

/// Predicts the position a gesture is "headed toward" given its current
/// position and velocity, using the half-second projection rule.
///
/// Used by [VelixSheet] to choose which detent to snap to on release.
double projectGesturePosition({
  required double currentPosition,
  required double pixelsPerSecond,
  Duration projection = const Duration(milliseconds: 500),
}) {
  return currentPosition +
      pixelsPerSecond * (projection.inMilliseconds / 1000.0);
}
