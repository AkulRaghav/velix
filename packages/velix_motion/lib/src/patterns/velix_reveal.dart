import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// Pattern: `motion.reveal`.
///
/// Substance becoming visible â€” slow start, decisive end (`Cubic(0.2,0,0,1)`).
/// One-shot, not interruptible by design (used for state crossfades that
/// finish before user can re-trigger).
class VelixReveal extends StatefulWidget {
  const VelixReveal({
    super.key,
    required this.child,
    required this.revealed,
    this.duration,
  });

  final Widget child;
  final bool revealed;
  final Duration? duration;

  @override
  State<VelixReveal> createState() => _VelixRevealState();
}

class _VelixRevealState extends State<VelixReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.revealed ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context).extension<VelixTheme>();
    if (theme != null) {
      _c.duration = widget.duration ?? theme.motion.durationReveal;
    }
  }

  @override
  void didUpdateWidget(covariant VelixReveal old) {
    super.didUpdateWidget(old);
    if (old.revealed != widget.revealed) {
      _animate();
    }
    if (old.duration != widget.duration && widget.duration != null) {
      _c.duration = widget.duration!;
    }
  }

  void _animate() {
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    final theme = Theme.of(context).extension<VelixTheme>();
    if (reduce || theme == null) {
      _c.animateTo(
        widget.revealed ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );
    } else {
      _c.animateTo(widget.revealed ? 1 : 0, curve: theme.motion.reveal);
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
      builder: (context, _) => Opacity(opacity: _c.value, child: widget.child),
    );
  }
}
