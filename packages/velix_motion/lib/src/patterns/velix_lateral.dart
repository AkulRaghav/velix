import 'package:flutter/widgets.dart';

/// Pattern: `motion.lateral`.
///
/// Slides a child between sibling positions. Caller-driven: pass `progress`
/// in [0, 1] (or use an [AnimationController] and feed its value).
///
/// The widget computes translation + opacity for one side of the transition.
/// Outgoing siblings pass an *inverse* progress (1.0 → 0.0).
class VelixLateral extends StatelessWidget {
  const VelixLateral({
    super.key,
    required this.child,
    required this.direction,
    required this.progress,
  });

  final Widget child;
  final AxisDirection direction;

  /// 0 = entirely off-screen on entry side; 1 = at rest position.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final extent = switch (direction) {
      AxisDirection.right || AxisDirection.left => size.width,
      AxisDirection.up || AxisDirection.down => size.height,
    };
    final p = progress.clamp(0.0, 1.0);
    final inverted = 1 - p;
    final translation = switch (direction) {
      AxisDirection.right => Offset(extent * inverted, 0),
      AxisDirection.left => Offset(-extent * inverted, 0),
      AxisDirection.down => Offset(0, extent * inverted),
      AxisDirection.up => Offset(0, -extent * inverted),
    };
    return Transform.translate(
      offset: translation,
      child: Opacity(opacity: 0.6 + 0.4 * p, child: child),
    );
  }
}
