import '../entities/identity.dart';

abstract interface class IdentityRepository {
  /// The signed-in identity, if any. Null until [createOrSignIn] succeeds.
  Stream<Identity?> watch();

  /// Idempotent: creates a new identity on first call and returns the
  /// existing one on subsequent calls.
  ///
  /// Real cryptographic generation lands in Phase 7; the Phase 5 stub
  /// produces a deterministic fake.
  Future<Identity> createOrSignIn({String? displayName, String? handle});

  Future<void> signOut();

  Future<void> update(Identity updated);
}
