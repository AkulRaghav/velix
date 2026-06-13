import 'package:flutter/painting.dart';

import 'brand.dart';

/// Velix color tokens.
///
/// Authored in OKLCH; hex values produced by perceptually-uniform conversion
/// and verified against WCAG 2.2 AA in `docs/phase-2/12-accessibility.md`.
///
/// Token paths (see overview doc) are mirrored as nested classes so consumers
/// write `colors.surface.substrate`, never raw hex.
class VelixColors {
  const VelixColors({
    required this.surface,
    required this.text,
    required this.accent,
    required this.semantic,
    required this.trust,
    required this.presence,
    required this.gradients,
    required this.rooms,
  });

  /// Production constructor: takes the chosen [Brand] and yields the full
  /// token set. Brand is locked to [Brand.quartzBlue] at end of Phase 2.
  factory VelixColors.dark({Brand brand = Brand.quartzBlue}) {
    return VelixColors(
      surface: const VelixSurfaceColors._(
        voidBlack: Color(0xFF000000),
        substrate: Color(0xFF08090C),
        quiet: Color(0xFF11131A),
        active: Color(0xFF1A1D27),
        lifted: Color(0xFF24283A),
        scrim: Color(0x9908090C),
      ),
      text: const VelixTextColors._(
        primary: Color(0xFFF2F4FA),
        secondary: Color(0xFFB7BBC9),
        tertiary: Color(0xFF898DA0),
        disabled: Color(0xFF555967),
        inverse: Color(0xFF08090C),
      ),
      accent: VelixAccentColors._forBrand(brand),
      semantic: const VelixSemanticColors._(
        success: Color(0xFF6FB58D),
        successMuted: Color(0xFF294834),
        successDeep: Color(0xFF497A60),
        warning: Color(0xFFDABA6E),
        warningMuted: Color(0xFF4A3F23),
        warningDeep: Color(0xFFA38A4D),
        danger: Color(0xFFD86F5A),
        dangerMuted: Color(0xFF4D2922),
        dangerDeep: Color(0xFFA8513F),
      ),
      trust: const VelixTrustColors._(
        verifiedTintHueShift: 0,
        verifiedChromaDelta: 0.02,
        verifiedLightnessDelta: 0,
        unverifiedTintHueShift: 250,
        unverifiedChromaDelta: 0.01,
        unverifiedLightnessDelta: -0.02,
      ),
      presence: const VelixPresenceColors._(
        online: Color(0xFF6FB58D),
        recently: Color(0xFF898DA0),
      ),
      gradients: VelixGradients._forBrand(brand),
      rooms: const VelixRoomColors._(),
    );
  }

  final VelixSurfaceColors surface;
  final VelixTextColors text;
  final VelixAccentColors accent;
  final VelixSemanticColors semantic;
  final VelixTrustColors trust;
  final VelixPresenceColors presence;
  final VelixGradients gradients;
  final VelixRoomColors rooms;
}

class VelixSurfaceColors {
  const VelixSurfaceColors._({
    required this.voidBlack,
    required this.substrate,
    required this.quiet,
    required this.active,
    required this.lifted,
    required this.scrim,
  });

  /// Pure OLED black. Used sparingly: splash and story-viewer letterbox.
  final Color voidBlack;

  /// The default scene. Slightly cool, sits at OKLCH L≈0.07.
  final Color substrate;

  /// Tier-1 quiet material fill (88% opaque equivalent).
  final Color quiet;

  /// Tier-2 active material fill (62% opaque equivalent).
  final Color active;

  /// Tier-3 lifted material fill (50% opaque equivalent).
  final Color lifted;

  /// Modal backdrop scrim.
  final Color scrim;
}

class VelixTextColors {
  const VelixTextColors._({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.disabled,
    required this.inverse,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color disabled;
  final Color inverse;
}

class VelixAccentColors {
  const VelixAccentColors._({
    required this.s50,
    required this.s40,
    required this.s30,
    required this.s20,
    required this.s10,
  });

  /// Quartz Blue — locked signature accent.
  factory VelixAccentColors._forBrand(Brand brand) {
    switch (brand) {
      case Brand.quartzBlue:
        return const VelixAccentColors._(
          s50: Color(0xFFD4E0FF),
          s40: Color(0xFF93B5FF),
          s30: Color(0xFF3478F6),
          s20: Color(0xFF1F58C8),
          s10: Color(0xFF0F3A8E),
        );
    }
  }

  /// Lightest step. Subtle backgrounds, very-muted accents.
  final Color s50;

  /// Muted step. Disabled accents, secondary mentions.
  final Color s40;

  /// Primary step. Buttons, focus rings, active states.
  final Color s30;

  /// Pressed step.
  final Color s20;

  /// Deep step. Solid accent backgrounds.
  final Color s10;

  /// Convenience alias matching `accent.signature` in docs.
  Color get signature => s30;
  Color get signatureMuted => s40;
}

class VelixSemanticColors {
  const VelixSemanticColors._({
    required this.success,
    required this.successMuted,
    required this.successDeep,
    required this.warning,
    required this.warningMuted,
    required this.warningDeep,
    required this.danger,
    required this.dangerMuted,
    required this.dangerDeep,
  });

  final Color success;
  final Color successMuted;
  final Color successDeep;
  final Color warning;
  final Color warningMuted;
  final Color warningDeep;
  final Color danger;
  final Color dangerMuted;
  final Color dangerDeep;
}

/// Trust state is encoded as OKLCH-space *deltas* applied to the underlying
/// material at runtime. We don't ship absolute trust colors because they
/// must adapt to whatever surface they tint.
class VelixTrustColors {
  const VelixTrustColors._({
    required this.verifiedTintHueShift,
    required this.verifiedChromaDelta,
    required this.verifiedLightnessDelta,
    required this.unverifiedTintHueShift,
    required this.unverifiedChromaDelta,
    required this.unverifiedLightnessDelta,
  });

  final double verifiedTintHueShift;
  final double verifiedChromaDelta;
  final double verifiedLightnessDelta;
  final double unverifiedTintHueShift;
  final double unverifiedChromaDelta;
  final double unverifiedLightnessDelta;
}

class VelixPresenceColors {
  const VelixPresenceColors._({
    required this.online,
    required this.recently,
  });

  final Color online;
  final Color recently;
}

class VelixGradients {
  const VelixGradients._({
    required this.signature,
    required this.veil,
  });

  factory VelixGradients._forBrand(Brand brand) {
    final accent = VelixAccentColors._forBrand(brand);
    return VelixGradients._(
      signature: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent.s30, accent.s10],
      ),
      veil: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF08090C), Color(0x0008090C)],
      ),
    );
  }

  final Gradient signature;
  final Gradient veil;
}

/// Per-conversation room palette. Used as a 6–12% tint on Tier-2 materials.
class VelixRoomColors {
  const VelixRoomColors._();

  Color get mist => const Color(0xFF8FB1D6);
  Color get sage => const Color(0xFF92C2A5);
  Color get linen => const Color(0xFFD7C898);
  Color get coral => const Color(0xFFE89779);
  Color get petal => const Color(0xFFDCA7B6);
  Color get iris => const Color(0xFF9B83C0);
  Color get pacific => const Color(0xFF4A7CA8);
  Color get forest => const Color(0xFF4D8266);
  Color get sand => const Color(0xFFB59B6A);
  Color get ember => const Color(0xFFB96B43);
  Color get plum => const Color(0xFF875E80);
  Color get slate => const Color(0xFF7E818E);

  List<Color> get all => [
        mist, sage, linen, coral, petal, iris,
        pacific, forest, sand, ember, plum, slate,
      ];

  /// Deterministically derive a room color from a conversation id hash.
  /// Two users see the same color for the same conversation.
  Color fromHash(int hash) => all[hash.abs() % all.length];
}
