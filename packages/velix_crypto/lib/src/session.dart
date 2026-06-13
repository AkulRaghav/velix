import 'dart:typed_data';

import 'exceptions.dart';
import 'types.dart';

/// 1:1 session between this device and a peer device.
///
/// Wraps a cryptocore session handle. The underlying state lives in
/// libsignal's session store; Dart only holds the handle.
class Session {
  Session._(this._handle, this.peerAccountId, this.peerDeviceId);

  final int _handle;
  final String peerAccountId;
  final String peerDeviceId;

  /// Initiate a new session from a peer's prekey bundle.
  static Session initiate({
    required IdentityPublicKey localIdentityPub,
    required String peerAccountId,
    required String peerDeviceId,
    required PrekeyBundle bundle,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore session FFI not yet wired (Sprint 1)',
    );
  }

  /// Encrypt a plaintext for the peer device.
  Ciphertext encrypt(Uint8List plaintext) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore session FFI not yet wired (Sprint 1)',
    );
  }

  /// Decrypt a ciphertext from the peer device.
  Uint8List decrypt(Ciphertext ciphertext) {
    throw const VelixCryptoException(
      CryptoErrorCode.decryptFailed,
      'cryptocore session FFI not yet wired (Sprint 1)',
    );
  }

  void dispose() {
    // velix_session_free(_handle) once FFI lands.
  }
}
