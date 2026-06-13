import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Pattern: `motion.parallax`.
///
/// Two- or three-layer parallax bound to a [ScrollController] (and
/// optionally a tilt source). Pure linear; the input is itself linear
/// gesture position.
///
/// Phase 5 will add a tilt source backed by `sensors_plus`. For Phase 4
/// the API supports it via [tiltOffset], a ValueListenable consumers
/// can drive externally (e.g., from the 3D system's gyro tap).
class VelixParallax extends StatefulWidget {
  const VelixParallax({
    super.key,
    required this.layers,
    this.scroll,
    this.tiltOffset,
  });

  final List<ParallaxLayer> layers;
  final ScrollController? scroll;
  final ValueListenable<Offset>? tiltOffset;

  @override
  State<VelixParallax> createState() => _VelixParallaxState();
}

class _VelixParallaxState extends State<VelixParallax> {
  double _scrollOffset = 0;
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.scroll?.addListener(_onScroll);
    widget.tiltOffset?.addListener(_onTilt);
  }

  void _onScroll() => setState(() => _scrollOffset = widget.scroll!.offset);
  void _onTilt() => setState(() => _tilt = widget.tiltOffset!.value);

  @override
  void didUpdateWidget(covariant VelixParallax old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll?.removeListener(_onScroll);
      widget.scroll?.addListener(_onScroll);
    }
    if (old.tiltOffset != widget.tiltOffset) {
      old.tiltOffset?.removeListener(_onTilt);
      widget.tiltOffset?.addListener(_onTilt);
    }
  }

  @override
  void dispose() {
    widget.scroll?.removeListener(_onScroll);
    widget.tiltOffset?.removeListener(_onTilt);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final reduceTilt = mq?.disableAnimations ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in widget.layers)
          Transform.translate(
            offset: Offset(
              reduceTilt ? 0 : (_tilt.dx * layer.factor),
              (reduceTilt ? 0 : (_tilt.dy * layer.factor)) +
                  (_scrollOffset * layer.factor * -1),
            ),
            child: layer.child,
          ),
      ],
    );
  }
}

class ParallaxLayer {
  const ParallaxLayer({required this.child, required this.factor});
  final Widget child;

  /// 1.0 = locked to input; 0.0 = stationary.
  final double factor;
}
