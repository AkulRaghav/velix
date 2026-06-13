/// AI features Velix exposes. Closed set; new features require architectural
/// review per `docs/phase-8/01-trust-boundary.md`.
enum AIFeature {
  smartReply,
  translation,
  translationCloud,
  summarization,
  summarizationCloud,
  moderation,
  liveCaptions,
  assistant,
  searchExpansion,
}

/// Where the inference runs.
enum InferenceLocation {
  onDevice,
  cloud,
}

/// Outcome of an AI invocation.
enum AIOutcome {
  success,
  consentDeclined,
  quotaExceeded,
  modelUnavailable,
  inferenceFailed,
  cancelled,
  error,
}
