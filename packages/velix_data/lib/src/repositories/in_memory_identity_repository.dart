import 'dart:async';

import 'package:velix_domain/velix_domain.dart';

/// Phase 5 in-memory identity repository.
///
/// Phase 7 will replace this with the libsignal-backed implementation
/// that owns the actual cryptographic key generation and storage.
class InMemoryIdentityRepository implements IdentityRepository {
  InMemoryIdentityRepository({Identity? seed}) : _identity = seed;

  Identity? _identity;
  final StreamController<Identity?> _ctl =
      StreamController<Identity?>.broadcast();

  @override
  Stream<Identity?> watch() async* {
    yield _identity;
    yield* _ctl.stream;
  }

  @override
  Future<Identity> createOrSignIn({String? displayName, String? handle}) async {
    if (_identity != null) return _identity!;
    final id = Identity(
      id: const IdentityId('local-identity'),
      handle: handle,
      // Placeholder bytes; the real cryptographic key lands in Phase 7.
      publicKey: const [0, 0, 0, 0],
      createdAt: Instant.now(),
      displayName: displayName,
    );
    _identity = id;
    _ctl.add(_identity);
    return id;
  }

  @override
  Future<void> signOut() async {
    _identity = null;
    _ctl.add(null);
  }

  @override
  Future<void> update(Identity updated) async {
    if (_identity?.id != updated.id) return;
    _identity = updated;
    _ctl.add(_identity);
  }

  void dispose() => _ctl.close();
}
