import 'package:flutter/widgets.dart';

/// iOS-style scroll physics applied uniformly across platforms.
///
/// Default Android scroll decelerates too quickly compared to iOS; Velix's
/// brand voice is consistent everywhere, so we use [BouncingScrollPhysics]
/// behavior on Android, macOS, Windows, Linux, and web.
///
/// Tunings match Phase 4 doc 08:
/// - friction 0.135
/// - rubber-band 0.5
/// - max fling velocity 8000 px/s
class VelixScrollPhysics extends BouncingScrollPhysics {
  const VelixScrollPhysics({super.parent});

  @override
  VelixScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return VelixScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get maxFlingVelocity => 8000;

  // Inherited friction from BouncingScrollPhysics is 0.135 — matches our spec.
  // We override only the fling cap so absurdly fast flicks don't render
  // as warps.
}
