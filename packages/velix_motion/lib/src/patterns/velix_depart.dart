import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// Pattern: `motion.depart`.
///
/// In most cases, prefer toggling [VelixArrive.present] â€” it composes both
/// arrival and departure. [VelixDepart] exists for cases where the child is
/// a separately-mounted route that needs a one-shot departure on dispose.
class VelixDepart extends StatefulWidget {
  const VelixDepart({
    super.key,
    required this.child,
    this.translationOffset = 24,
    this.scaleAmount = 0.02,
  });

  final Widget child;
  final double translationOffset;
  final double scaleAmount;

  @override
  State<VelixDepart> createState() => _VelixDepartState();
}

class _VelixDepartState extends State<VelixDepart>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    final theme = Theme.of(context).extension<VelixTheme>();
    if (reduce || theme == null) {
      _c.animateTo(1, duration: const Duration(milliseconds: 100), curve: Curves.linear);
    } else {
      _c.duration = theme.motion.durationDepart;
      _c.animateTo(1, curve: theme.motion.depart);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final translateY = widget.translationOffset * t;
        final scale = 1 - widget.scaleAmount * t;
        final opacity = 1 - t;
        return Opacity(
          opacity: opacity,
          child: Transform(
            transform: Matrix4.identity()
              ..translate(0.0, translateY)
              ..scale(scale, scale),
            alignment: Alignment.center,
            child: widget.child,
          ),
        );
      },
    );
  }
}
