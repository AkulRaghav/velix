import 'package:meta/meta.dart';

import '../value_objects/ids.dart';
import '../value_objects/instant.dart';

@immutable
class Identity {
  const Identity({
    required this.id,
    required this.handle,
    required this.publicKey,
    required this.createdAt,
    this.displayName,
    this.bio,
    this.avatarUrl,
  });

  /// `hash(public_key)`. Stable across devices, never derived from PII.
  final IdentityId id;

  /// The discoverable handle (e.g. `@quinn`). Optional.
  final String? handle;

  /// Ed25519 long-term public key bytes (32 bytes).
  final List<int> publicKey;

  final Instant createdAt;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;

  Identity copyWith({
    String? handle,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) =>
      Identity(
        id: id,
        handle: handle ?? this.handle,
        publicKey: publicKey,
        createdAt: createdAt,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}
