import 'package:flutter/widgets.dart';

/// Velix spacing tokens.
///
/// 4 px baseline grid. Numbers between the documented stops do not exist;
/// `EdgeInsets.all(14)` is a build-time lint failure.
class VelixSpace {
  const VelixSpace();

  // Primitive scale (logical px).
  double get s0 => 0;
  double get s1 => 2;
  double get s2 => 4;
  double get s3 => 6;
  double get s4 => 8;
  double get s5 => 12;
  double get s6 => 16;
  double get s7 => 20;
  double get s8 => 24;
  double get s9 => 32;
  double get s10 => 40;
  double get s11 => 48;
  double get s12 => 64;
  double get s13 => 80;

  // Semantic — components reach for these names, not the scale.
  double get insetXs => 4;
  double get insetSm => 8;
  double get insetMd => 12;
  double get insetLg => 16;
  double get insetXl => 24;

  double get stackXs => 4;
  double get stackSm => 8;
  double get stackMd => 12;
  double get stackLg => 20;
  double get stackXl => 32;

  double get gutterScreen => 24;
  double get gutterList => 16;
  double get gutterDense => 12;

  /// Convenience helpers. Components use these so the codebase never
  /// constructs raw EdgeInsets at the call site.
  EdgeInsets get cardPadding => EdgeInsets.all(insetLg);
  EdgeInsets get heroPadding => EdgeInsets.all(insetXl);
  EdgeInsets get sheetPadding =>
      EdgeInsets.symmetric(horizontal: insetXl, vertical: insetLg);
  EdgeInsets get screenInset =>
      EdgeInsets.symmetric(horizontal: gutterScreen);
  EdgeInsets get listCellPadding =>
      EdgeInsets.symmetric(horizontal: gutterList, vertical: insetMd);

  /// Minimum touch target across all platforms.
  Size get minTouchTarget => const Size(48, 48);
}
