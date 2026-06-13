import 'dart:ui';

import 'package:flutter/painting.dart';

import 'colors.dart';

/// Velix material tier definitions.
///
/// Four tiers + three modifiers. See `docs/phase-2/02-material-tiers.md`.
/// Consumers reach for `theme.materials.lifted` rather than constructing
/// `BackdropFilter` manually.
class VelixMaterials {
  const VelixMaterials({required VelixColors colors}) : _c = colors;

  final VelixColors _c;

  VelixMaterial get substrate => VelixMaterial(
        blurSigma: 0,
        fill: _c.surface.substrate,
        saturation: 1.0,
        edge: null,
      );

  VelixMaterial get quiet => VelixMaterial(
        blurSigma: 6,
        fill: _c.surface.quiet.withOpacity(0.88),
        saturation: 1.0,
        edge: const Color(0x0AFFFFFF),
      );

  VelixMaterial get active => VelixMaterial(
        blurSigma: 24,
        fill: _c.surface.active.withOpacity(0.62),
        saturation: 1.15,
        edge: const Color(0x12FFFFFF),
        topInsetHighlight: const Color(0x08FFFFFF),
      );

  VelixMaterial get lifted => VelixMaterial(
        blurSigma: 40,
        fill: _c.surface.lifted.withOpacity(0.50),
        saturation: 1.25,
        edge: const Color(0x17FFFFFF),
        topInsetHighlight: const Color(0x0DFFFFFF),
        bottomInsetShadow: const Color(0x1F000000),
      );

  /// Opaque fallback for Reduce Transparency / older Android.
  VelixMaterial opaqueFor(VelixMaterial m) {
    if (identical(m, quiet)) {
      return VelixMaterial(
        blurSigma: 0,
        fill: _c.surface.quiet,
        saturation: 1.0,
        edge: const Color(0x14FFFFFF),
      );
    }
    if (identical(m, active)) {
      return VelixMaterial(
        blurSigma: 0,
        fill: _c.surface.active,
        saturation: 1.0,
        edge: const Color(0x1FFFFFFF),
      );
    }
    if (identical(m, lifted)) {
      return VelixMaterial(
        blurSigma: 0,
        fill: _c.surface.lifted,
        saturation: 1.0,
        edge: const Color(0x29FFFFFF),
      );
    }
    return m;
  }
}

class VelixMaterial {
  const VelixMaterial({
    required this.blurSigma,
    required this.fill,
    required this.saturation,
    required this.edge,
    this.topInsetHighlight,
    this.bottomInsetShadow,
  });

  final double blurSigma;
  final Color fill;
  final double saturation;

  /// 1-px outer edge color. Null means no edge stroke.
  final Color? edge;

  /// Top inset highlight (1-px inner top edge). Glass tiers only.
  final Color? topInsetHighlight;

  /// Bottom inset shadow (1-px inner bottom edge). Tier-3 only.
  final Color? bottomInsetShadow;

  /// Returns the saturation `ColorFilter` for the material, or null when
  /// saturation is 1.0. Consumers stack `BackdropFilter`s manually so the
  /// filter chain order (saturate-after-blur) stays explicit at the call site.
  ColorFilter? get saturationFilter {
    if (saturation == 1.0) return null;
    final s = saturation;
    final inv = 1 - s;
    final r = 0.213 * inv;
    final g = 0.715 * inv;
    final b = 0.072 * inv;
    return ColorFilter.matrix(<double>[
      r + s, g,     b,     0, 0,
      r,     g + s, b,     0, 0,
      r,     g,     b + s, 0, 0,
      0,     0,     0,     1, 0,
    ]);
  }

  /// The blur `ImageFilter`, or null when `blurSigma == 0`.
  ImageFilter? get blurFilter => blurSigma == 0
      ? null
      : ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
}
