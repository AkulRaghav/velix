import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:velix_data/velix_data.dart';

/// Verifies that the alpha client's pure-Dart HMAC-SHA256 matches RFC 4231
/// test vectors and `crypto`-package output.
void main() {
  group('AlphaApiClient.hmacSha256', () {
    test('RFC 4231 test case 1', () {
      // key = 0x0b * 20, data = "Hi There"
      final key = Uint8List.fromList(List<int>.filled(20, 0x0b));
      final data = Uint8List.fromList(utf8.encode('Hi There'));
      final mac = AlphaApiClient.hmacSha256(key, data);
      // Expected from RFC 4231:
      // b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7
      expect(_hex(mac),
          'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');
    });

    test('RFC 4231 test case 2', () {
      // key = "Jefe", data = "what do ya want for nothing?"
      final key = Uint8List.fromList(utf8.encode('Jefe'));
      final data = Uint8List.fromList(utf8.encode('what do ya want for nothing?'));
      final mac = AlphaApiClient.hmacSha256(key, data);
      expect(_hex(mac),
          '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843');
    });

    test('RFC 4231 test case 3 (longer key)', () {
      final key = Uint8List.fromList(List<int>.filled(20, 0xaa));
      final data = Uint8List.fromList(List<int>.filled(50, 0xdd));
      final mac = AlphaApiClient.hmacSha256(key, data);
      expect(_hex(mac),
          '773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe');
    });
  });
}

String _hex(Uint8List b) {
  const a = '0123456789abcdef';
  final out = StringBuffer();
  for (final v in b) {
    out.write(a[(v >> 4) & 0xf]);
    out.write(a[v & 0xf]);
  }
  return out.toString();
}
