import 'dart:async';

import 'package:velix_domain/velix_domain.dart';

import 'alpha_api_client.dart';
import 'alpha_session.dart';

/// Identity repository backed by an existing alpha session.
class RemoteIdentityRepository implements IdentityRepository {
  RemoteIdentityRepository({
    required this.client,
    required this.session,
  }) {
    _identity = _toDomain(session);
    _ctl.add(_identity);
  }

  final AlphaApiClient client;
  AlphaSession session;

  Identity? _identity;
  final StreamController<Identity?> _ctl =
      StreamController<Identity?>.broadcast();

  Identity _toDomain(AlphaSession s) => Identity(
        id: IdentityId(s.accountId),
        handle: s.handle,
        publicKey: s.identityPublicKey,
        createdAt: Instant.now(),
        displayName: s.handle,
      );

  @override
  Stream<Identity?> watch() async* {
    yield _identity;
    yield* _ctl.stream;
  }

  @override
  Future<Identity> createOrSignIn({String? displayName, String? handle}) async {
    // The alpha bootstrap creates the session before constructing this repo.
    // If signOut was called this throws — caller should re-authenticate.
    final cur = _identity;
    if (cur == null) {
      throw StateError(
        'RemoteIdentityRepository.createOrSignIn called after signOut; '
        're-run Bootstrap.run() to obtain a fresh repository.',
      );
    }
    return cur;
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
