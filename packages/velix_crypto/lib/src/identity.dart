import 'dart:typed_data';

import 'exceptions.dart';
import 'types.dart';

/// Identity keypair Dart-side handle.
///
/// Wraps a cryptocore-managed identity. Private bytes never leave the
/// crate; Dart receives only opaque references and the public key.
class IdentityKeyPair {
  IdentityKeyPair._(this._handle, this.publicKey);

  final int _handle;
  final IdentityPublicKey publicKey;

  /// Generates a fresh identity keypair via the cryptocore CSPRNG.
  ///
  /// Production: calls `velix_identity_generate` over FFI; receives a
  /// 64-bit handle + the public key bytes.
  static IdentityKeyPair generate() {
    // External dependency: real generation runs once cryptocore lands the
    // FFI surface. Until then, this throws [CryptoErrorCode.protocolError]
    // so callers fail loudly rather than silently using a stub.
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore identity FFI not yet wired (Sprint 1)',
    );
  }

  /// Signs a message with this identity's private key.
  Signature sign(Uint8List message) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore identity FFI not yet wired (Sprint 1)',
    );
  }

  /// Releases the cryptocore handle.
  void dispose() {
    // velix_identity_free(_handle) once FFI lands.
  }

  /// Verifies an Ed25519 signature against [pubkey] over [message].
  static void verifySignature({
    required IdentityPublicKey pubkey,
    required Uint8List message,
    required Signature signature,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore identity FFI not yet wired (Sprint 1)',
    );
  }
}
