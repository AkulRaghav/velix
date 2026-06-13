import 'dart:async';

import 'package:flutter/foundation.dart';

import 'scene_id.dart';
import 'scene_metrics.dart';
import 'scene_params.dart';

/// Lifecycle states of a single 3D scene. Mirrors the state machine in
/// `docs/phase-3/01-renderer-architecture.md`.
enum SceneLifecycle {
  notLoaded,
  loading,
  paused,
  rendering,
  disposed,
}

/// Single Dart-side handle for a 3D scene.
///
/// Phase 3 ships an *abstract* controller and a stub implementation
/// ([NoopSceneController]) that always reports unhealthy. Phase 5 plugs in
/// the Filament-backed implementation; the API surface here is the only
/// thing other packages consume, so the swap is isolated.
abstract class VelixSceneController {
  ValueListenable<SceneLifecycle> get lifecycle;

  /// Whether the most recent metrics indicate healthy 3D rendering.
  /// Hosting widgets watch this and cross-fade to fallback when false.
  ValueListenable<bool> get healthy;

  Stream<SceneMetrics> get metrics;

  /// Loads a scene by id and parameters. Completes when ready (or fails).
  ///
  /// When [startPaused] is `true`, the scene resolves to [SceneLifecycle.paused]
  /// and any subsequent [resume] is a no-op until the caller toggles a flag.
  /// This is the path Reduce-Motion takes: load the scene as a single static
  /// frame and never start the render loop.
  Future<void> load(
    SceneId id, {
    SceneParams params = const SceneParams(),
    bool startPaused = false,
  });

  /// Releases all resources. Required on widget dispose.
  Future<void> dispose();

  /// Pauses rendering and snapshots a single frame.
  ///
  /// [keepLastFrame] is honored by production controllers; when `true` the
  /// last rendered frame is kept on the GPU as a 2D bitmap for the duration
  /// of the pause. The noop controller ignores it.
  void pause({bool keepLastFrame = true});

  void resume();

  /// Updates parallax inputs. Throttled internally.
  /// Tilt values are in radians; scrollY is in logical pixels.
  void setParallax({
    required double tiltX,
    required double tiltY,
    double scrollY = 0,
  });
}

/// Default controller used when 3D is disabled or before the Filament
/// binding is wired (Phase 3, before Phase 5).
///
/// Reports unhealthy so hosting widgets cross-fade to the 2D fallback.
class NoopSceneController implements VelixSceneController {
  NoopSceneController();

  final ValueNotifier<SceneLifecycle> _lifecycle =
      ValueNotifier<SceneLifecycle>(SceneLifecycle.notLoaded);
  final ValueNotifier<bool> _healthy = ValueNotifier<bool>(false);
  final StreamController<SceneMetrics> _metrics =
      StreamController<SceneMetrics>.broadcast();
  bool _staticFrameOnly = false;

  @override
  ValueListenable<SceneLifecycle> get lifecycle => _lifecycle;

  @override
  ValueListenable<bool> get healthy => _healthy;

  @override
  Stream<SceneMetrics> get metrics => _metrics.stream;

  @override
  Future<void> load(
    SceneId id, {
    SceneParams params = const SceneParams(),
    bool startPaused = false,
  }) async {
    _lifecycle.value = SceneLifecycle.loading;
    _staticFrameOnly = startPaused;
    // Yield to the event loop so callers can subscribe to lifecycle if they want.
    await Future<void>.delayed(Duration.zero);
    _lifecycle.value = SceneLifecycle.paused;
    // Stay unhealthy: hosting widgets fall back to 2D until Phase 5 binding.
    _healthy.value = false;
  }

  @override
  Future<void> dispose() async {
    _lifecycle.value = SceneLifecycle.disposed;
    await _metrics.close();
  }

  @override
  void pause({bool keepLastFrame = true}) {
    // keepLastFrame is honored by production controllers; the noop controller
    // simply transitions the lifecycle.
    if (_lifecycle.value == SceneLifecycle.rendering) {
      _lifecycle.value = SceneLifecycle.paused;
    }
  }

  @override
  void resume() {
    if (_staticFrameOnly) return;
    if (_lifecycle.value == SceneLifecycle.paused) {
      // Still unhealthy until Filament is bound; widgets remain on fallback.
      _lifecycle.value = SceneLifecycle.rendering;
    }
  }

  @override
  void setParallax({
    required double tiltX,
    required double tiltY,
    double scrollY = 0,
  }) {
    // No-op until the Filament binding is wired in Phase 5.
  }
}
