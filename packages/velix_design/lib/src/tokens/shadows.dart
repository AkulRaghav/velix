import 'package:flutter/painting.dart';

/// Velix shadow tokens.
///
/// Two layers: contact (close, hard) + ambient (far, soft).
/// Real surfaces compose both via the elevation presets.
class VelixShadows {
  const VelixShadows();

  BoxShadow get contact => const BoxShadow(
        offset: Offset(0, 1),
        blurRadius: 1.5,
        spreadRadius: 0,
        color: Color(0x52000000), // 0.32 alpha
      );

  BoxShadow get ambientLow => const BoxShadow(
        offset: Offset(0, 6),
        blurRadius: 16,
        spreadRadius: -4,
        color: Color(0x52000000),
      );

  BoxShadow get ambientMed => const BoxShadow(
        offset: Offset(0, 12),
        blurRadius: 32,
        spreadRadius: -8,
        color: Color(0x66000000), // 0.40
      );

  BoxShadow get ambientHigh => const BoxShadow(
        offset: Offset(0, 24),
        blurRadius: 64,
        spreadRadius: -16,
        color: Color(0x7A000000), // 0.48
      );

  /// Pressed-state inset shadow.
  /// Flutter doesn't render box-shadow inset; consumers apply this via
  /// `BackdropFilter` over the surface in pressed state.
  BoxShadow get insetSoft => const BoxShadow(
        offset: Offset(0, 1),
        blurRadius: 2,
        color: Color(0x3D000000), // 0.24
      );

  /// Top-edge inset highlight applied to glass materials.
  /// Implemented as a 1-px `Container` border with this color, never as a shadow.
  Color get glassEdgeHighlight => const Color(0x14FFFFFF); // 0.08 alpha

  // Composed presets.
  List<BoxShadow> get elevation0 => const [];
  List<BoxShadow> get elevation1 => [contact];
  List<BoxShadow> get elevation2 => [contact, ambientLow];
  List<BoxShadow> get elevation3 => [contact, ambientMed];
  List<BoxShadow> get elevation4 => [contact, ambientHigh];
}
