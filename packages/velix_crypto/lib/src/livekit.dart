import 'dart:typed_data';

import 'exceptions.dart';

/// LiveKit Insertable Streams E2EE.
///
/// Per-frame AES-256-GCM encrypt/decrypt for the SFU pipeline.
class LiveKitE2EE {
  /// Encrypt a frame.
  static Uint8List encryptFrame({
    required Uint8List frameKey,
    required int frameCounter,
    required int trackId,
    required Uint8List senderId,
    required Uint8List plaintext,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore livekit FFI not yet wired (Sprint 1)',
    );
  }

  /// Decrypt a frame.
  static Uint8List decryptFrame({
    required Uint8List frameKey,
    required int frameCounter,
    required int trackId,
    required Uint8List senderId,
    required Uint8List ciphertext,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.decryptFailed,
      'cryptocore livekit FFI not yet wired (Sprint 1)',
    );
  }
}
