import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

import '../haptics/velix_haptics.dart';
import '../util/velocity_handoff.dart';

/// Tier-3 bottom sheet with detent physics and gesture-driven dismissal.
///
/// Detents:
/// - `dismissed` â€” implicit, off-screen
/// - `medium` â€” 50% of viewport height
/// - `large` â€” 88% of viewport height
///
/// Drag is 1:1 between detents; release applies velocity hand-off via the
/// half-second gesture projection rule (see `docs/phase-4/07-modal-and-sheet-physics.md`).
class VelixSheet extends StatefulWidget {
  const VelixSheet({
    super.key,
    required this.child,
    required this.detents,
    this.initialDetent = SheetDetent.medium,
    this.dismissible = true,
    this.onDetentChanged,
    this.onDismiss,
  })  : assert(detents.length > 0, 'A sheet needs at least one detent.');

  final Widget child;
  final List<SheetDetent> detents;
  final SheetDetent initialDetent;
  final bool dismissible;
  final ValueChanged<SheetDetent>? onDetentChanged;
  final VoidCallback? onDismiss;

  @override
  State<VelixSheet> createState() => _VelixSheetState();
}

enum SheetDetent {
  dismissed,
  medium,
  large,
}

extension _DetentFraction on SheetDetent {
  /// Fraction of viewport height occupied by the sheet at this detent.
  double get fraction => switch (this) {
        SheetDetent.dismissed => 0.0,
        SheetDetent.medium => 0.5,
        SheetDetent.large => 0.88,
      };
}

class _VelixSheetState extends State<VelixSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final VelocityTracker _vt = VelocityTracker.withKind(PointerDeviceKind.touch);
  double _lastSnap = 0;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController.unbounded(
      vsync: this,
      value: widget.initialDetent.fraction,
    );
    _lastSnap = widget.initialDetent.fraction;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<double> get _detentFractions => [
        if (widget.dismissible) 0.0,
        for (final d in widget.detents) d.fraction,
      ];

  SheetDetent get _currentDetent {
    final all = SheetDetent.values
        .where((d) => widget.detents.contains(d) || d == SheetDetent.dismissed)
        .toList();
    var nearest = all.first;
    var nearestDist = (_ctl.value - nearest.fraction).abs();
    for (final d in all) {
      final dist = (_ctl.value - d.fraction).abs();
      if (dist < nearestDist) {
        nearest = d;
        nearestDist = dist;
      }
    }
    return nearest;
  }

  void _onDragStart(DragStartDetails d) {
    _ctl.stop();
    _vt.addPosition(d.sourceTimeStamp ?? Duration.zero, d.globalPosition);
  }

  void _onDragUpdate(DragUpdateDetails d, double viewportHeight) {
    _vt.addPosition(d.sourceTimeStamp ?? Duration.zero, d.globalPosition);
    // Drag delta is in pixels downward; sheet shrinks as user drags down.
    final fractionDelta = -d.primaryDelta! / viewportHeight;
    var next = _ctl.value + fractionDelta;
    final maxFraction = widget.detents
        .map((d) => d.fraction)
        .reduce(math.max);
    // Rubber-band past the largest detent.
    if (next > maxFraction) {
      final overpull = next - maxFraction;
      next = maxFraction + overpull * 0.4;
    }
    _ctl.value = next.clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d, double viewportHeight) {
    final velocityPxPerS = -d.velocity.pixelsPerSecond.dy; // up is positive
    final velocityFraction = velocityPxPerS / viewportHeight;

    // Project the gesture forward in unit-space by half a second.
    // Note: position and velocity must be in the same unit; we work entirely
    // in viewport fractions here.
    final projectedFraction = _ctl.value + velocityFraction * 0.5;

    // Pick the target. If velocity is high, pick the next detent in the
    // velocity direction. Otherwise nearest to projection.
    SheetDetent target;
    final available = [
      if (widget.dismissible) SheetDetent.dismissed,
      ...widget.detents,
    ]..sort((a, b) => a.fraction.compareTo(b.fraction));

    // Velocity-relative threshold: 1200 px/s on an 800-pt viewport == 1.5,
    // expressed as fraction-per-second.
    const flickThreshold = 1.5;
    final viewportRelative = velocityFraction.abs();
    if (viewportRelative > flickThreshold) {
      // High velocity: choose the immediate-next detent in the velocity
      // direction, not the extreme.
      if (velocityPxPerS > 0) {
        target = available.firstWhere(
          (e) => e.fraction > _ctl.value,
          orElse: () => available.last,
        );
      } else {
        target = available.lastWhere(
          (e) => e.fraction < _ctl.value,
          orElse: () => available.first,
        );
      }
    } else {
      target = available.first;
      var dist = (projectedFraction - target.fraction).abs();
      for (final dd in available) {
        final ddist = (projectedFraction - dd.fraction).abs();
        if (ddist < dist) {
          target = dd;
          dist = ddist;
        }
      }
    }

    final theme = Theme.of(context).extension<VelixTheme>();
    final mq = MediaQuery.of(context);
    if (mq.disableAnimations || theme == null) {
      _ctl.animateTo(
        target.fraction,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );
    } else {
      final spring = buildHandoffSpring(
        spring: theme.motion.lateral,
        start: _ctl.value,
        end: target.fraction,
        pixelsPerSecond: velocityPxPerS,
        normalizationDistance: viewportHeight,
      );
      _ctl.animateWith(spring);
    }

    if (target == SheetDetent.dismissed) {
      widget.onDismiss?.call();
    } else {
      widget.onDetentChanged?.call(target);
      // Fire haptic when snap target differs from previous lock.
      if ((target.fraction - _lastSnap).abs() > 0.001) {
        VelixHaptics.sheetDetent();
        _lastSnap = target.fraction;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final viewport = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final fraction = _ctl.value;
        final translateY = (1 - fraction) * viewport;
        return Transform.translate(
          offset: Offset(0, translateY),
          child: GestureDetector(
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: (d) => _onDragUpdate(d, viewport),
            onVerticalDragEnd: (d) => _onDragEnd(d, viewport),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: viewport,
              decoration: BoxDecoration(
                color: v.materials.lifted.fill,
                borderRadius: v.radius.sheetTop,
                boxShadow: v.shadows.elevation4,
              ),
              child: Column(
                children: [
                  const _DragHandle(),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Semantics(
          label: 'Drag to resize',
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: v.colors.text.tertiary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
