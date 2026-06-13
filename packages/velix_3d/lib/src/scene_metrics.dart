/// Frame metrics surfaced by the renderer.
///
/// These drive the auto-downgrade ladder defined in
/// `docs/phase-3/06-performance-and-fallback.md`.
class SceneMetrics {
  const SceneMetrics({
    required this.gpuFrameMs,
    required this.cpuFrameMs,
    required this.frameStability99,
    required this.droppedFramesLastSecond,
  });

  /// Most recent GPU frame time in milliseconds.
  final double gpuFrameMs;

  /// Most recent CPU frame time on the render isolate, in milliseconds.
  /// Note: 0 when the renderer is paused.
  final double cpuFrameMs;

  /// Fraction of recent frames that landed inside 16.6 ms.
  /// 1.0 = perfect, 0.99 = production-ready, < 0.95 = unhealthy.
  final double frameStability99;

  /// Count of dropped frames in the last second.
  final int droppedFramesLastSecond;

  bool get healthy =>
      gpuFrameMs <= 4.0 &&
      cpuFrameMs <= 2.0 &&
      frameStability99 >= 0.99 &&
      droppedFramesLastSecond <= 2;

  @override
  String toString() =>
      'SceneMetrics(gpu: ${gpuFrameMs.toStringAsFixed(2)}ms, '
      'cpu: ${cpuFrameMs.toStringAsFixed(2)}ms, '
      'stability: ${(frameStability99 * 100).toStringAsFixed(1)}%, '
      'dropped: $droppedFramesLastSecond)';
}
