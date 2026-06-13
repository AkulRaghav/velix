import 'dart:typed_data';

import 'exceptions.dart';

/// Encrypted backup helpers.
class Backup {
  /// Argon2id parameters tuned to ≈ 1000 ms on iPhone 12.
  static const int defaultMemoryKib = 64 * 1024;
  static const int defaultIterations = 3;
  static const int defaultParallelism = 1;

  /// Encrypt a backup payload with a passphrase.
  ///
  /// Output layout:
  ///   [1 byte version | 16 bytes salt | 24 bytes nonce | ciphertext+tag]
  static Uint8List encrypt({
    required Uint8List passphrase,
    required Uint8List plaintext,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore backup FFI not yet wired (Sprint 1)',
    );
  }

  /// Decrypt a backup payload with a passphrase.
  static Uint8List decrypt({
    required Uint8List passphrase,
    required Uint8List payload,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.decryptFailed,
      'cryptocore backup FFI not yet wired (Sprint 1)',
    );
  }
}
