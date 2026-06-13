import 'dart:convert';
import 'dart:io';

/// Persisted alpha session: account id, handle, bearer token, identity keys.
///
/// The keys are stored on disk (alpha-grade — no secure-storage dependency
/// at this point) under the application's documents directory. Phase 7
/// replaces this with the libsignal-backed key store.
class AlphaSession {
  AlphaSession({
    required this.accountId,
    required this.handle,
    required this.token,
    required this.identityPublicKey,
    required this.identityPrivateKey,
  });

  final String accountId;
  final String handle;
  final String token;
  final List<int> identityPublicKey;  // 32 bytes
  final List<int> identityPrivateKey; // 64 bytes (ed25519 seed+pub form)

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'handle': handle,
        'token': token,
        'identity_public_key': identityPublicKey,
        'identity_private_key': identityPrivateKey,
      };

  factory AlphaSession.fromJson(Map<String, dynamic> j) => AlphaSession(
        accountId: j['account_id'] as String,
        handle: j['handle'] as String,
        token: j['token'] as String,
        identityPublicKey: (j['identity_public_key'] as List<dynamic>).cast<int>(),
        identityPrivateKey:
            (j['identity_private_key'] as List<dynamic>).cast<int>(),
      );
}

/// Reads / writes [AlphaSession] from a JSON file. Caller chooses the path.
class AlphaSessionStore {
  AlphaSessionStore({required this.path});
  final String path;

  Future<AlphaSession?> load() async {
    final f = File(path);
    if (!await f.exists()) return null;
    final raw = await f.readAsString();
    if (raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AlphaSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AlphaSession s) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(s.toJson()));
  }

  Future<void> clear() async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
