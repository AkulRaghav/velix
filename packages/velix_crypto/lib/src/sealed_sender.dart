import 'dart:typed_data';

import 'exceptions.dart';
import 'types.dart';

/// Sealed Sender envelope helpers.
class SealedSender {
  /// Wrap [innerCiphertext] in a sealed-sender envelope addressed to
  /// [recipientIdentityPub] using the server-issued [senderCert].
  static Ciphertext seal({
    required Ciphertext innerCiphertext,
    required IdentityPublicKey recipientIdentityPub,
    required SenderCertificate senderCert,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.protocolError,
      'cryptocore sealed_sender FFI not yet wired (Sprint 1)',
    );
  }

  /// Unwrap a sealed-sender envelope; returns sender info + inner ciphertext.
  static UnsealedEnvelope unseal({
    required Ciphertext sealed,
    required Uint8List localIdentityPriv,
  }) {
    throw const VelixCryptoException(
      CryptoErrorCode.decryptFailed,
      'cryptocore sealed_sender FFI not yet wired (Sprint 1)',
    );
  }
}

class UnsealedEnvelope {
  const UnsealedEnvelope({
    required this.senderAccountId,
    required this.senderDeviceId,
    required this.innerCiphertext,
  });

  final String senderAccountId;
  final String senderDeviceId;
  final Ciphertext innerCiphertext;
}
