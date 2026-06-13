import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:velix_crypto/velix_crypto.dart';

void main() {
  group('types', () {
    test('IdentityPublicKey rejects wrong size', () {
      expect(
        () => IdentityPublicKey.fromBytes(Uint8List(31)),
        throwsArgumentError,
      );
    });

    test('Signature rejects wrong size', () {
      expect(
        () => Signature.fromBytes(Uint8List(63)),
        throwsArgumentError,
      );
    });
  });

  group('exceptions', () {
    test('CryptoErrorCode.fromInt maps known values', () {
      expect(CryptoErrorCode.fromInt(0), CryptoErrorCode.ok);
      expect(CryptoErrorCode.fromInt(3), CryptoErrorCode.decryptFailed);
    });

    test('CryptoErrorCode.fromInt falls back to internalError', () {
      expect(CryptoErrorCode.fromInt(99), CryptoErrorCode.internalError);
    });

    test('checkOk throws on non-ok', () {
      expect(() => checkOk(3, context: 'test'), throwsA(isA<VelixCryptoException>()));
    });

    test('checkOk does not throw on ok', () {
      expect(() => checkOk(0), returnsNormally);
    });
  });

  group('FFI surface (skeleton)', () {
    // Real FFI tests run after the cryptocore Rust crate ships its FFI.
    // Until then these stubs throw deliberately.
    test('IdentityKeyPair.generate throws skeleton-protocol-error', () {
      expect(
        () => IdentityKeyPair.generate(),
        throwsA(isA<VelixCryptoException>()
            .having((e) => e.code, 'code', CryptoErrorCode.protocolError)),
      );
    });
  });
}
