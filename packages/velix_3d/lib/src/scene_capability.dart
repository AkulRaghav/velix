import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Whether 3D should be attempted on this device + at this moment.
///
/// Decisions follow the matrix in `docs/phase-3/06-performance-and-fallback.md`.
/// We err on the side of *not* rendering 3D — the 2D fallback is on-brand and
/// safe. Hard "yes" requires positive capability + favorable runtime state.
class SceneCapability {
  const SceneCapability({
    required this.is3DSupported,
    required this.reasonIfNot,
  });

  final bool is3DSupported;
  final String? reasonIfNot;

  /// Detect at app launch. Cached for the session.
  ///
  /// The actual GPU benchmark (Filament compatibility test) is intentionally
  /// not run here in Phase 3; the FFI binding lands in Phase 5 and will
  /// extend this with a [bench] method. For now we use platform heuristics.
  ///
  /// We use [defaultTargetPlatform] (with [kIsWeb] guarded first) so this
  /// file compiles cleanly on web targets where `dart:io` is not available.
  static SceneCapability detect(BuildContext context) {
    // Web has no 3D, by policy.
    if (kIsWeb) {
      return const SceneCapability(
        is3DSupported: false,
        reasonIfNot: 'web-not-supported',
      );
    }

    // Reduce Transparency / Increase Contrast disables 3D entirely.
    final mq = MediaQuery.maybeOf(context);
    if (mq?.highContrast ?? false) {
      return const SceneCapability(
        is3DSupported: false,
        reasonIfNot: 'reduce-transparency',
      );
    }

    // Platform-level guards. The Phase 5 FFI binding will harden this with a
    // real GPU compatibility benchmark + chip-class detection.
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return const SceneCapability(is3DSupported: true, reasonIfNot: null);
      case TargetPlatform.fuchsia:
        return const SceneCapability(
          is3DSupported: false,
          reasonIfNot: 'unsupported-platform',
        );
    }
  }
}
