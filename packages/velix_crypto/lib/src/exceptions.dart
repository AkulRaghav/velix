/// Mirror of the cryptocore CryptoError enum.
///
/// Every FFI call returns one of these codes. Dart wraps non-ok results
/// in [VelixCryptoException] before throwing.
enum CryptoErrorCode {
  ok(0),
  invalidArgument(1),
  bufferTooSmall(2),
  decryptFailed(3),
  signatureInvalid(4),
  sessionNotFound(5),
  protocolError(6),
  keyMissing(7),
  keyExpired(8),
  internalError(9);

  const CryptoErrorCode(this.value);
  final int value;

  static CryptoErrorCode fromInt(int v) {
    for (final c in CryptoErrorCode.values) {
      if (c.value == v) return c;
    }
    return CryptoErrorCode.internalError;
  }
}

/// Exception thrown from any non-ok FFI return.
///
/// We deliberately do not differentiate between "wrong key" and "tampered
/// ciphertext" for decryption errors; both surface as
/// [CryptoErrorCode.decryptFailed].
class VelixCryptoException implements Exception {
  const VelixCryptoException(this.code, [this.context]);

  final CryptoErrorCode code;
  final String? context;

  @override
  String toString() {
    final ctx = context == null ? '' : ' ($context)';
    return 'VelixCryptoException: ${code.name}$ctx';
  }
}

/// Throws if [code] is non-ok.
void checkOk(int code, {String? context}) {
  final c = CryptoErrorCode.fromInt(code);
  if (c == CryptoErrorCode.ok) return;
  throw VelixCryptoException(c, context);
}
