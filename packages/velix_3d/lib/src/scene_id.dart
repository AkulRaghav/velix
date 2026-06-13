/// All sanctioned 3D scenes in Velix.
///
/// Locked Phase 3 scope: three surfaces (onboarding x3, profile, space).
/// Adding a new value requires a documented design review per
/// `docs/phase-3/00-system-overview.md`.
enum SceneId {
  onboardingStep1,
  onboardingStep2,
  onboardingStep3,
  profileIdentity,
  spaceAmbient,
}

/// Categorical grouping for budget enforcement.
extension SceneIdCategory on SceneId {
  bool get isOnboarding =>
      this == SceneId.onboardingStep1 ||
      this == SceneId.onboardingStep2 ||
      this == SceneId.onboardingStep3;

  bool get isPersistent =>
      this == SceneId.profileIdentity || this == SceneId.spaceAmbient;
}
