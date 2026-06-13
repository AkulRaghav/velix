import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// Pattern: `motion.arrive`.
///
/// Translates 24 px from below + scales 0.96 â†’ 1.00 + opacity 0 â†’ 1.
/// Spring physics, interruptible, Reduce-Motion aware.
///
/// Toggle [present] to drive in/out. Driving false runs `motion.depart`.
class VelixArrive extends StatefulWidget {
  const VelixArrive({
    super.key,
    required this.child,
    this.present = true,
    this.delay = Duration.zero,
    this.translationOffset = 24,
    this.scaleAmount = 0.04,
    this.onArrived,
  });

  final Widget child;
  final bool present;
  final Duration delay;

  /// How far below the rest position the child enters from. Default 24 px.
  /// Velix message bubbles use 12 px (subtle).
  final double translationOffset;

  /// 1.00 - scaleAmount â†’ 1.00. Default 0.04 (so 0.96 â†’ 1.00).
  /// Pass 0 to disable scale (used for message bubbles, lists).
  final double scaleAmount;

  final VoidCallback? onArrived;

  @override
  State<VelixArrive> createState() => _VelixArriveState();
}

class _VelixArriveState extends State<VelixArrive>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(vsync: this, value: widget.present ? 1 : 0);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onArrived?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scheduled) {
      _scheduled = true;
      if (widget.present && _c.value < 1) _animateTo(1);
    }
  }

  @override
  void didUpdateWidget(covariant VelixArrive old) {
    super.didUpdateWidget(old);
    if (old.present != widget.present) {
      _animateTo(widget.present ? 1 : 0);
    }
  }

  Future<void> _animateTo(double target) async {
    if (widget.delay > Duration.zero && target == 1) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
    }
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    final theme = Theme.of(context).extension<VelixTheme>();
    if (reduce || theme == null) {
      _c.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
      return;
    }
    if (target == 1) {
      _c.animateWith(SpringSimulation(theme.motion.arrive, _c.value, 1, _c.velocity));
    } else {
      // Departure uses curve, not spring.
      _c.animateTo(
        0,
        duration: theme.motion.durationDepart,
        curve: theme.motion.depart,
      );
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
        // Clamp for transform usage; the controller can briefly exceed 1
        // due to spring overshoot, which we keep visible.
        final t = _c.value.clamp(0.0, 1.5);
        final invert = 1 - t;
        final translateY = widget.translationOffset * invert.clamp(0, 1);
        final scale = (1 - widget.scaleAmount) + widget.scaleAmount * t.clamp(0, 1);
        final opacity = t.clamp(0.0, 1.0);
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
