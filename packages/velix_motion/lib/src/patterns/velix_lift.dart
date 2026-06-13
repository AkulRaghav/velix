import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

import '../haptics/velix_haptics.dart';

/// Pattern: `motion.lift` / `motion.settle`.
///
/// Lifts a child by [scaleAmount] when [lifted] is true; reverses with the
/// `motion.settle` spring when false. Fires a `lift` haptic at the spring's
/// 50% travel mark on engagement (never on settle).
class VelixLift extends StatefulWidget {
  const VelixLift({
    super.key,
    required this.child,
    required this.lifted,
    this.scaleAmount = 0.04,
    this.fireHaptic = true,
  });

  final Widget child;
  final bool lifted;
  final double scaleAmount;
  final bool fireHaptic;

  @override
  State<VelixLift> createState() => _VelixLiftState();
}

class _VelixLiftState extends State<VelixLift>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _hapticFiredThisLift = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(vsync: this, value: widget.lifted ? 1 : 0);
    _c.addListener(_maybeFireHaptic);
  }

  void _maybeFireHaptic() {
    if (!widget.lifted || !widget.fireHaptic) return;
    if (_hapticFiredThisLift) return;
    if (_c.value > 0.5) {
      VelixHaptics.lift();
      _hapticFiredThisLift = true;
    }
  }

  @override
  void didUpdateWidget(covariant VelixLift old) {
    super.didUpdateWidget(old);
    if (old.lifted != widget.lifted) {
      _animate(widget.lifted);
    }
  }

  void _animate(bool toLifted) {
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    final theme = Theme.of(context).extension<VelixTheme>();
    if (toLifted) _hapticFiredThisLift = false;

    if (reduce || theme == null) {
      _c.animateTo(
        toLifted ? 1 : 0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
      return;
    }
    final spring = toLifted ? theme.motion.lift : theme.motion.settle;
    _c.animateWith(SpringSimulation(spring, _c.value, toLifted ? 1 : 0, _c.velocity));
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
        final t = _c.value.clamp(0.0, 1.5);
        final scale = 1 + widget.scaleAmount * t.clamp(0, 1);
        return Transform.scale(scale: scale, child: widget.child);
      },
    );
  }
}
