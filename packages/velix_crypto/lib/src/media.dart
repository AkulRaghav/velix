import 'dart:typed_data';

import 'exceptions.dart';

/// Encrypted media helpers.
///
/// Per-media key (32 bytes random); chunked AEAD with XChaCha20-Poly1305.
class Media {
  /// Generates a fresh per-media key.
  static Uint8List freshMediaKey() {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore media FFI not yet wired (Sprint 1)',
    );
  }

  /// Encrypt a media chunk.
  static Uint8List encryptChunk({
    required Uint8List key,
    required Uint8List associatedData,
    required Uint8List plaintext,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore media FFI not yet wired (Sprint 1)',
    );
  }

  /// Decrypt a media chunk.
  static Uint8List decryptChunk({
    required Uint8List key,
    required Uint8List associatedData,
    required Uint8List ciphertext,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.decryptFailed,
      'cryptocore media FFI not yet wired (Sprint 1)',
    );
  }
}
