/// Velix signature accent.
///
/// Locked at the end of Phase 2: **Quartz Blue** (`#3478F6`).
///
/// The enum is preserved (rather than collapsed to a constant) so the
/// brand-swap mechanism remains in place for unforeseen future variants
/// and so the API surface doesn't churn for downstream callers. We will
/// not add new variants without a documented design review.
enum Brand {
  quartzBlue,
}
