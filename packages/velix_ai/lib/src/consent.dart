import 'package:meta/meta.dart';

import 'types.dart';

/// Per-query consent token. See `docs/phase-8/03-consent-and-opt-in.md`.
///
/// The token is HMAC-SHA-256 of (query_id || expires_at) under a
/// per-device consent seed. The seed is local to the device (Phase 5 doc 05
/// secure storage hierarchy) and never transmitted.
///
/// The token is single-use; the gateway tracks `query_id` for 5 minutes
/// to defeat replay.
@immutable
class ConsentToken {
  const ConsentToken({
    required this.queryId,
    required this.expiresAt,
    required this.tokenBytes,
  });

  /// The query id (ULID) bound to this consent.
  final String queryId;

  /// Expiry; the gateway rejects tokens past this.
  final DateTime expiresAt;

  /// HMAC bytes; the wire-format value.
  final List<int> tokenBytes;
}

/// The user's consent decision for a single cloud AI invocation.
@immutable
class ConsentDecision {
  const ConsentDecision({
    required this.feature,
    required this.acceptedAt,
    required this.token,
  });

  final AIFeature feature;
  final DateTime acceptedAt;
  final ConsentToken token;
}

/// Abstract consent provider. Implementations:
/// - Production: invokes the per-query consent UX (a `VelixModal`),
///   waits for the user's tap, mints a token via the secure-storage seed.
/// - Tests: returns a synthetic token (or null to simulate decline).
abstract interface class ConsentProvider {
  /// Returns a consent decision for [feature], or null if the user declined.
  ///
  /// MUST present the user with a fresh per-query gesture. Caching across
  /// queries is forbidden.
  Future<ConsentDecision?> requestConsent({
    required AIFeature feature,
    required String redactedPreview,
    required String userExplanation,
  });
}

/// Returns null. Used for on-device features that don't need consent.
class NoConsentRequired implements ConsentProvider {
  const NoConsentRequired();

  @override
  Future<ConsentDecision?> requestConsent({
    required AIFeature feature,
    required String redactedPreview,
    required String userExplanation,
  }) async => null;
}
