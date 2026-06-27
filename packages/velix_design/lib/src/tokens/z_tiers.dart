/// Velix Z-tier model. Four tiers + two overlay tiers.
/// See `docs/phase-2/08-z-tiers.md`.
///
/// Z-tiers define the stacking order of surfaces in the UI:
/// - substrate: The base layer (background)
/// - nav: Navigation elements (bottom bar, side rail)
/// - content: Primary content surfaces (cards, lists)
/// - modal: Modal dialogs, bottom sheets, drawers
/// - overlay: Toasts, snackbars, floating actions
/// - system: System UI overlays (status bar tints)
enum ZTier {
  substrate, // 0
  nav,       // 1
  content,   // 2
  modal,     // 3
  overlay,   // 4
  system,    // 5
}

extension ZTierIndex on ZTier {
  int get level => switch (this) {
        ZTier.substrate => 0,
        ZTier.nav => 1,
        ZTier.content => 2,
        ZTier.modal => 3,
        ZTier.overlay => 4,
        ZTier.system => 5,
      };

  /// Elevation value in logical pixels for shadow rendering.
  double get elevation => switch (this) {
        ZTier.substrate => 0,
        ZTier.nav => 4,
        ZTier.content => 8,
        ZTier.modal => 16,
        ZTier.overlay => 24,
        ZTier.system => 32,
      };

  /// Whether this tier should render a backdrop blur.
  bool get hasBackdropBlur => switch (this) {
        ZTier.substrate => false,
        ZTier.nav => true,
        ZTier.content => false,
        ZTier.modal => true,
        ZTier.overlay => true,
        ZTier.system => false,
      };
}
