import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';

/// Velix component contract: GlassCard.
/// See `docs/phase-2/09-component-contracts.md`.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.tier = GlassCardTier.quiet,
    this.radius,
    this.padding,
    this.tintColor,
    this.tintOpacity = 0.06,
  });

  final Widget child;
  final GlassCardTier tier;
  final double? radius;
  final EdgeInsetsGeometry? padding;

  /// Optional room-color tint applied through the material.
  final Color? tintColor;
  final double tintOpacity;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final mq = MediaQuery.of(context);
    final material = switch (tier) {
      GlassCardTier.quiet => v.materials.quiet,
      GlassCardTier.active => v.materials.active,
    };
    final reduceTransparency = mq.highContrast;
    final effective =
        reduceTransparency ? v.materials.opaqueFor(material) : material;
    final r = BorderRadius.circular(radius ?? v.radius.lg.x);
    final pad = padding ?? v.space.cardPadding;

    final body = Container(
      decoration: BoxDecoration(
        color: tintColor != null
            ? Color.alphaBlend(
                tintColor!.withValues(alpha: tintOpacity),
                effective.fill,
              )
            : effective.fill,
        borderRadius: r,
        border: effective.edge != null
            ? Border.all(color: effective.edge!, width: 1)
            : null,
        boxShadow:
            tier == GlassCardTier.active ? v.shadows.elevation2 : v.shadows.elevation1,
      ),
      padding: pad,
      child: child,
    );

    if (effective.blurSigma == 0) return body;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effective.blurSigma,
          sigmaY: effective.blurSigma,
        ),
        child: body,
      ),
    );
  }
}

enum GlassCardTier { quiet, active }
