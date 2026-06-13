import 'package:flutter/material.dart';

import 'tokens/brand.dart';
import 'tokens/colors.dart';
import 'tokens/materials.dart';
import 'tokens/motion.dart';
import 'tokens/radius.dart';
import 'tokens/shadows.dart';
import 'tokens/spacing.dart';
import 'tokens/typography.dart';

/// `VelixTheme` is the single object the rest of the app reaches for.
///
/// We use `ThemeExtension<VelixTheme>` so `Theme.of(context).extension<VelixTheme>()`
/// returns the full token surface in one shot. Components reach via the
/// [BuildContext] extension at the bottom of this file.
@immutable
class VelixTheme extends ThemeExtension<VelixTheme> {
  VelixTheme({
    required this.brand,
    required this.colors,
    required this.space,
    required this.radius,
    required this.shadows,
    required this.typography,
    required this.motion,
    required this.materials,
  });

  /// Production constructor. Brand was locked to [Brand.quartzBlue] at the
  /// end of Phase 2. The optional parameter is preserved for forward
  /// compatibility but currently has only one valid value.
  factory VelixTheme.dark({Brand brand = Brand.quartzBlue}) {
    final colors = VelixColors.dark(brand: brand);
    return VelixTheme(
      brand: brand,
      colors: colors,
      space: const VelixSpace(),
      radius: const VelixRadius(),
      shadows: const VelixShadows(),
      typography: VelixTypography(colors: colors),
      motion: const VelixMotion(),
      materials: VelixMaterials(colors: colors),
    );
  }

  final Brand brand;
  final VelixColors colors;
  final VelixSpace space;
  final VelixRadius radius;
  final VelixShadows shadows;
  final VelixTypography typography;
  final VelixMotion motion;
  final VelixMaterials materials;

  /// Bridge to the underlying Material `ThemeData`. The application uses the
  /// Material widgets at the foundation (Scaffold, Navigator, etc.) but every
  /// visible surface goes through Velix tokens.
  ///
  /// The returned [ThemeData] **already carries** this [VelixTheme] in its
  /// `extensions` list, so callers can pass it straight to `MaterialApp.theme`
  /// and `context.velix` resolves correctly throughout the app:
  ///
  /// ```dart
  /// final theme = VelixTheme.dark();
  /// runApp(MaterialApp(
  ///   theme: theme.toMaterialTheme(),
  ///   home: const VelixApp(),
  /// ));
  /// ```
  ThemeData toMaterialTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.surface.substrate,
      canvasColor: colors.surface.substrate,
      // Disable Material's default ripple. Velix uses spotlight + scale presses.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      // Material text theme is unused by Velix components; we set it as a
      // safety net for any third-party widget that reads from it.
      textTheme: TextTheme(
        displayLarge: typography.displayL,
        displayMedium: typography.displayM,
        displaySmall: typography.displayS,
        titleLarge: typography.titleL,
        titleMedium: typography.titleM,
        titleSmall: typography.titleS,
        bodyLarge: typography.bodyL,
        bodyMedium: typography.bodyM,
        bodySmall: typography.bodyS,
        labelLarge: typography.labelL,
        labelMedium: typography.labelM,
        labelSmall: typography.labelS,
      ),
      colorScheme: ColorScheme.dark(
        primary: colors.accent.signature,
        onPrimary: colors.text.inverse,
        secondary: colors.accent.signatureMuted,
        onSecondary: colors.text.primary,
        surface: colors.surface.substrate,
        onSurface: colors.text.primary,
        error: colors.semantic.danger,
        onError: colors.text.inverse,
      ),
      extensions: <ThemeExtension<dynamic>>[this],
    );
  }

  @override
  VelixTheme copyWith({
    Brand? brand,
    VelixColors? colors,
    VelixSpace? space,
    VelixRadius? radius,
    VelixShadows? shadows,
    VelixTypography? typography,
    VelixMotion? motion,
    VelixMaterials? materials,
  }) {
    return VelixTheme(
      brand: brand ?? this.brand,
      colors: colors ?? this.colors,
      space: space ?? this.space,
      radius: radius ?? this.radius,
      shadows: shadows ?? this.shadows,
      typography: typography ?? this.typography,
      motion: motion ?? this.motion,
      materials: materials ?? this.materials,
    );
  }

  /// We intentionally do not interpolate brands. Brand changes are an instant
  /// swap (only ever happens in development; production locks at compile
  /// time). Lerp returns `b` past 0.5.
  @override
  VelixTheme lerp(ThemeExtension<VelixTheme>? other, double t) {
    if (other is! VelixTheme) return this;
    return t < 0.5 ? this : other;
  }
}

/// Provides the chosen [VelixTheme] in widget trees that **don't** use
/// [MaterialApp].
///
/// If your app *does* use [MaterialApp] (or [CupertinoApp]), pass the theme
/// directly via `MaterialApp.theme: theme.toMaterialTheme()` instead of
/// wrapping. `MaterialApp` creates its own `Theme` widget which would
/// override anything this provider injects from above it.
///
/// ```dart
/// // Recommended for MaterialApp:
/// final theme = VelixTheme.dark();
/// runApp(MaterialApp(
///   theme: theme.toMaterialTheme(),
///   home: const VelixApp(),
/// ));
///
/// // Acceptable for non-MaterialApp roots (custom Navigator, tests):
/// VelixThemeProvider(
///   theme: theme,
///   child: MyCustomRoot(),
/// );
/// ```
class VelixThemeProvider extends StatelessWidget {
  const VelixThemeProvider({
    super.key,
    required this.theme,
    required this.child,
  });

  final VelixTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: theme.toMaterialTheme(), child: child);
  }
}

/// Convenience access. `context.velix.colors.surface.substrate`.
extension VelixThemeContext on BuildContext {
  VelixTheme get velix {
    final ext = Theme.of(this).extension<VelixTheme>();
    assert(
      ext != null,
      'VelixTheme not found in widget tree. Pass `theme.toMaterialTheme()` to '
      'MaterialApp.theme, or wrap a non-MaterialApp root in VelixThemeProvider.',
    );
    return ext!;
  }
}
