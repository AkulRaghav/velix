/// Velix Z-tier model. Four tiers. See `docs/phase-2/08-z-tiers.md`.
enum ZTier {
  substrate, // 0
  nav,       // 1
  content,   // 2
  modal,     // 3
}

extension ZTierIndex on ZTier {
  int get level => switch (this) {
        ZTier.substrate => 0,
        ZTier.nav => 1,
        ZTier.content => 2,
        ZTier.modal => 3,
      };
}
