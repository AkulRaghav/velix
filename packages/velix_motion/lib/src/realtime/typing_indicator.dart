import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// Three-dot typing indicator. The third permitted loop in the system
/// (the other two are the audio waveform and the AI streaming token reveal).
///
/// Spec: each dot fades 0.3 â†’ 1.0 â†’ 0.3 over 1.4 s, offset by a third of
/// the period. Reduce-Motion: dots static at 0.7 opacity.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({
    super.key,
    this.color,
    this.size = 6,
    this.gap = 6,
  });

  final Color? color;
  final double size;
  final double gap;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _opacityAt(double phase, double t) {
    // Triangle wave from 0.3 to 1.0 with a single-period rise+fall.
    final adjusted = (t - phase) % 1.0;
    final triangle = 1 - (adjusted * 2 - 1).abs();
    return 0.3 + 0.7 * triangle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<VelixTheme>();
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    final color = widget.color ??
        (theme != null
            ? Color.lerp(theme.colors.accent.signature, theme.colors.surface.substrate, 0.4)!
            : const Color(0xFF8DA8E2));

    Widget dotAt(double opacity) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      );
    }

    if (reduce) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dotAt(0.7),
          SizedBox(width: widget.gap),
          dotAt(0.7),
          SizedBox(width: widget.gap),
          dotAt(0.7),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return RepaintBoundary(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dotAt(_opacityAt(0.0, t)),
              SizedBox(width: widget.gap),
              dotAt(_opacityAt(1 / 3, t)),
              SizedBox(width: widget.gap),
              dotAt(_opacityAt(2 / 3, t)),
            ],
          ),
        );
      },
    );
  }
}
