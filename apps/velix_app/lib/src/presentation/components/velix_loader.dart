import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';

enum VelixLoaderSize { xs, sm, md }

/// Velix component contract: Loader (spinner + pulse).
/// See `docs/phase-2/09-component-contracts.md`.
class VelixLoader extends StatefulWidget {
  const VelixLoader.spinner({
    super.key,
    this.size = VelixLoaderSize.sm,
    this.color,
  }) : _kind = _LoaderKind.spinner;

  const VelixLoader.pulse({
    super.key,
    this.size = VelixLoaderSize.md,
    this.color,
  }) : _kind = _LoaderKind.pulse;

  final VelixLoaderSize size;
  final Color? color;
  final _LoaderKind _kind;

  @override
  State<VelixLoader> createState() => _VelixLoaderState();
}

enum _LoaderKind { spinner, pulse }

class _VelixLoaderState extends State<VelixLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final dur = widget._kind == _LoaderKind.spinner
        ? const Duration(milliseconds: 1400)
        : const Duration(milliseconds: 1600);
    _c = AnimationController(vsync: this, duration: dur)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _diameter => switch (widget.size) {
        VelixLoaderSize.xs => 16,
        VelixLoaderSize.sm => 20,
        VelixLoaderSize.md => 28,
      };

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    final color = widget.color ?? v.colors.accent.signature;

    if (widget._kind == _LoaderKind.spinner) {
      if (reduce) {
        return SizedBox(
          width: _diameter,
          height: _diameter,
          child: CustomPaint(painter: _RingPainter(progress: 0.5, color: color)),
        );
      }
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) => SizedBox(
          width: _diameter,
          height: _diameter,
          child: Transform.rotate(
            angle: _c.value * 6.283185307,
            child: CustomPaint(
              painter: _RingPainter(progress: 0.25, color: color),
            ),
          ),
        ),
      );
    }

    // Pulse — a static surface tint when Reduce-Motion is on.
    if (reduce) {
      return Container(
        decoration: BoxDecoration(
          color: v.colors.surface.quiet,
          borderRadius: v.radius.mdAll,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final shimmer = 0.4 + 0.6 * (1 - (t * 2 - 1).abs());
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(
              v.colors.surface.quiet,
              v.colors.surface.active,
              shimmer,
            ),
            borderRadius: v.radius.mdAll,
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final rect = const Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.2);
    canvas.drawArc(rect, 0, 6.283185307, false, paint);
    paint.color = color;
    canvas.drawArc(rect, -1.5708, 6.283185307 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
