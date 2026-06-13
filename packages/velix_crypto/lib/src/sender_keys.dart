import 'dart:typed_data';

import 'exceptions.dart';
import 'types.dart';

/// Group session for Sender Keys messaging.
class GroupSession {
  GroupSession._(this._handle, this.groupId);

  final int _handle;
  final Uint8List groupId; // 16 bytes

  static GroupSession create({required Uint8List groupId, required IdentityPublicKey senderId}) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore sender_keys FFI not yet wired (Sprint 1)',
    );
  }

  /// Produce the distribution message to send to peers.
  Uint8List distributionMessage() {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore sender_keys FFI not yet wired (Sprint 1)',
    );
  }

  /// Process a peer's distribution message into the local store.
  void processDistribution(Uint8List distribution) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore sender_keys FFI not yet wired (Sprint 1)',
    );
  }

  Ciphertext encrypt(Uint8List plaintext) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore sender_keys FFI not yet wired (Sprint 1)',
    );
  }

  Uint8List decrypt(Ciphertext ciphertext) {
    throw const VelixCryptoException(
      CryptoErrorCode.decryptFailed,
      'cryptocore sender_keys FFI not yet wired (Sprint 1)',
    );
  }

  void dispose() {}
}
