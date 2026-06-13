import 'package:flutter/painting.dart';

import 'colors.dart';

/// Velix typography tokens.
///
/// Inter (variable, optical-size aware) for UI; Vazirmatn for Arabic;
/// Noto Sans CJK for Japanese / Korean / Chinese fall-backs.
/// JetBrains Mono for cryptographic identifiers only.
class VelixTypography {
  VelixTypography({required VelixColors colors})
      : _colors = colors,
        _mono = const FontFeature.tabularFigures();

  final VelixColors _colors;
  // ignore: unused_field
  final FontFeature _mono;

  static const String _interFamily = 'Inter';
  static const String _interDisplayFamily = 'Inter';
  static const String _monoFamily = 'JetBrainsMono';

  static const List<String> _fallback = [
    'Vazirmatn',
    'NotoSansJP',
    'NotoSansKR',
    'NotoSansSC',
  ];

  // Display
  TextStyle get displayL => _build(
        size: 56, height: 60, ls: -0.84, weight: FontWeight.w600, opsz: 32,
        family: _interDisplayFamily,
      );
  TextStyle get displayM => _build(
        size: 44, height: 48, ls: -0.528, weight: FontWeight.w600, opsz: 28,
        family: _interDisplayFamily,
      );
  TextStyle get displayS => _build(
        size: 34, height: 40, ls: -0.34, weight: FontWeight.w600, opsz: 28,
        family: _interDisplayFamily,
      );

  // Title
  TextStyle get titleL =>
      _build(size: 28, height: 34, ls: -0.14, weight: FontWeight.w600, opsz: 22);
  TextStyle get titleM =>
      _build(size: 22, height: 28, ls: -0.066, weight: FontWeight.w600, opsz: 18);
  TextStyle get titleS =>
      _build(size: 19, height: 24, ls: -0.038, weight: FontWeight.w600, opsz: 16);

  // Body
  TextStyle get bodyL =>
      _build(size: 17, height: 22, ls: 0, weight: FontWeight.w400, opsz: 14);
  TextStyle get bodyM =>
      _build(size: 15, height: 20, ls: 0, weight: FontWeight.w400, opsz: 14);
  TextStyle get bodyS =>
      _build(size: 13, height: 18, ls: 0.013, weight: FontWeight.w400, opsz: 12);

  // Label
  TextStyle get labelL =>
      _build(size: 15, height: 20, ls: 0, weight: FontWeight.w500, opsz: 14);
  TextStyle get labelM =>
      _build(size: 13, height: 18, ls: 0.026, weight: FontWeight.w500, opsz: 12);
  TextStyle get labelS =>
      _build(size: 11, height: 14, ls: 0.055, weight: FontWeight.w600, opsz: 12);

  /// Tabular numerals overlay. Apply `.tabular` to any inherited style.
  TextStyle tabular(TextStyle base) => base.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Mono variant for cryptographic identifiers, etc. Inherits the size of
  /// its surrounding context.
  TextStyle mono(TextStyle base) => base.copyWith(
        fontFamily: _monoFamily,
        fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
        letterSpacing: 0,
        fontFeatures: const [],
      );

  TextStyle _build({
    required double size,
    required double height,
    required double ls,
    required FontWeight weight,
    required double opsz,
    String family = _interFamily,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: _fallback,
      fontSize: size,
      height: height / size,
      letterSpacing: ls,
      fontWeight: weight,
      fontVariations: [FontVariation('opsz', opsz)],
      color: _colors.text.primary,
      // No decoration. Underlines are reserved for hyperlinks.
      decoration: TextDecoration.none,
    );
  }
}
