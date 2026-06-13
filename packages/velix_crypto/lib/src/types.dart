import 'dart:typed_data';

import 'package:meta/meta.dart';

/// 32-byte ed25519 public identity key.
extension type IdentityPublicKey(Uint8List bytes) {
  /// Constructs from raw bytes; throws if length isn't 32.
  factory IdentityPublicKey.fromBytes(Uint8List input) {
    if (input.length != 32) {
      throw ArgumentError('IdentityPublicKey must be 32 bytes; got ${input.length}');
    }
    return IdentityPublicKey(input);
  }
}

/// 32-byte X25519 device public key.
extension type DevicePublicKey(Uint8List bytes) {
  factory DevicePublicKey.fromBytes(Uint8List input) {
    if (input.length != 32) {
      throw ArgumentError('DevicePublicKey must be 32 bytes; got ${input.length}');
    }
    return DevicePublicKey(input);
  }
}

/// 64-byte ed25519 signature.
extension type Signature(Uint8List bytes) {
  factory Signature.fromBytes(Uint8List input) {
    if (input.length != 64) {
      throw ArgumentError('Signature must be 64 bytes; got ${input.length}');
    }
    return Signature(input);
  }
}

/// Opaque ciphertext blob. Server stores; client decrypts.
extension type Ciphertext(Uint8List bytes) {}

/// Materialized prekey bundle for X3DH.
@immutable
class PrekeyBundle {
  const PrekeyBundle({
    required this.identityPublicKey,
    required this.signedPrekey,
    required this.signedPrekeySignature,
    required this.oneTimePrekey,
  });

  final IdentityPublicKey identityPublicKey;
  final Uint8List signedPrekey;
  final Signature signedPrekeySignature;
  final Uint8List? oneTimePrekey;
}

/// Sender certificate (sealed sender). Short-lived (≤ 24h).
extension type SenderCertificate(Uint8List bytes) {}
