import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

/// Minimal HTTP+JSON client for the Velix Alpha server.
///
/// Wraps `dart:io` `HttpClient`; no third-party dependency. The server
/// API is documented in `backend/alpha/README.md`.
///
/// Auth model is alpha-grade HMAC-SHA256-with-shared-secret:
///   - First run: generate a random 32-byte device_secret, register with it.
///   - Subsequent run: use device_secret to HMAC the server's nonce.
class AlphaApiClient {
  AlphaApiClient({required this.baseUri, HttpClient? httpClient})
      : _http = httpClient ?? HttpClient();

  final Uri baseUri;
  final HttpClient _http;

  String? _token;

  set token(String? value) => _token = value;
  String? get token => _token;

  void close() => _http.close(force: true);

  // ----- Crypto helper (HMAC-SHA256, pure Dart, alpha-grade) ----------------

  /// Generate a fresh 32-byte device secret using a non-cryptographic source.
  /// Alpha-grade only; production replaces with the libsignal CSPRNG.
  static Uint8List generateDeviceSecret() {
    final r = Random.secure();
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = r.nextInt(256);
    }
    return out;
  }

  /// HMAC-SHA256(deviceSecret, nonce). Pure Dart implementation; no crypto
  /// package dependency. Implementation reads the SHA-256 + HMAC algorithms
  /// inline.
  static Uint8List hmacSha256(Uint8List key, Uint8List msg) {
    final blockSize = 64;
    Uint8List k;
    if (key.length > blockSize) {
      k = _sha256(key);
    } else {
      k = Uint8List(blockSize)..setRange(0, key.length, key);
    }
    final ipad = Uint8List(blockSize);
    final opad = Uint8List(blockSize);
    for (var i = 0; i < blockSize; i++) {
      ipad[i] = k[i] ^ 0x36;
      opad[i] = k[i] ^ 0x5c;
    }
    final inner = _sha256(_concat([ipad, msg]));
    return _sha256(_concat([opad, inner]));
  }

  // ----- API ----------------------------------------------------------------

  Future<RegisterResult> register({
    required String handle,
    required Uint8List deviceSecret,
  }) async {
    final body = await _post('/v1/register', {
      'handle': handle,
      'device_secret_b64': base64.encode(deviceSecret),
    });
    final r = RegisterResult.fromJson(body);
    _token = r.token;
    return r;
  }

  Future<Uint8List> challenge({required String accountId}) async {
    final body = await _get('/v1/challenge', query: {'account_id': accountId});
    return base64.decode(body['nonce_b64'] as String);
  }

  Future<LoginResult> login({
    required String accountId,
    required Uint8List nonce,
    required Uint8List deviceSecret,
  }) async {
    final mac = hmacSha256(deviceSecret, nonce);
    final body = await _post('/v1/login', {
      'account_id': accountId,
      'nonce_b64': base64.encode(nonce),
      'hmac_b64': base64.encode(mac),
    });
    final r = LoginResult.fromJson(body);
    _token = r.token;
    return r;
  }

  Future<MeResult> me() async {
    final body = await _get('/v1/me');
    return MeResult.fromJson(body);
  }

  Future<MeResult> lookup({required String handle}) async {
    final body = await _get('/v1/users/lookup', query: {'handle': handle});
    return MeResult.fromJson(body);
  }

  Future<List<ConversationDto>> listConversations() async {
    final body = await _get('/v1/conversations');
    final arr = (body['conversations'] as List<dynamic>).cast<Map<String, dynamic>>();
    return arr.map(ConversationDto.fromJson).toList();
  }

  Future<ConversationDto> openConversation({
    required String peerAccountId,
    required String title,
  }) async {
    final body = await _post('/v1/conversations', {
      'peer_account_id': peerAccountId,
      'title': title,
    });
    return ConversationDto.fromJson(body);
  }

  Future<List<MessageDto>> listMessages({required String conversationId}) async {
    final body = await _get('/v1/conversations/$conversationId/messages');
    final arr = (body['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
    return arr.map(MessageDto.fromJson).toList();
  }

  Future<MessageDto> sendMessage({
    required String conversationId,
    required String kind,
    required Uint8List ciphertext,
    String? preview,
  }) async {
    final body = await _post('/v1/conversations/$conversationId/messages', {
      'kind': kind,
      'ciphertext_b64': base64.encode(ciphertext),
      'preview': preview ?? '',
    });
    return MessageDto.fromJson(body);
  }

  // ----- Plumbing -----------------------------------------------------------

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = baseUri.replace(path: path, queryParameters: query);
    final req = await _http.openUrl('GET', uri);
    _applyHeaders(req);
    final res = await req.close();
    return _readJson(res);
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    final uri = baseUri.replace(path: path);
    final req = await _http.openUrl('POST', uri);
    req.headers.contentType = ContentType.json;
    _applyHeaders(req);
    final encoded = utf8.encode(jsonEncode(body));
    req.contentLength = encoded.length;
    req.add(encoded);
    final res = await req.close();
    return _readJson(res);
  }

  void _applyHeaders(HttpClientRequest req) {
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final t = _token;
    if (t != null && t.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $t');
    }
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse res) async {
    final raw = await res.transform(utf8.decoder).join();
    final body = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw AlphaApiException(
      statusCode: res.statusCode,
      message: (body['error'] as String?) ?? 'http ${res.statusCode}',
    );
  }
}

class AlphaApiException implements Exception {
  AlphaApiException({required this.statusCode, required this.message});
  final int statusCode;
  final String message;

  @override
  String toString() => 'AlphaApiException($statusCode): $message';
}

class RegisterResult {
  RegisterResult({required this.accountId, required this.handle, required this.token});
  factory RegisterResult.fromJson(Map<String, dynamic> j) => RegisterResult(
        accountId: j['account_id'] as String,
        handle: j['handle'] as String,
        token: j['token'] as String,
      );
  final String accountId;
  final String handle;
  final String token;
}

class LoginResult {
  LoginResult({required this.token});
  factory LoginResult.fromJson(Map<String, dynamic> j) =>
      LoginResult(token: j['token'] as String);
  final String token;
}

class MeResult {
  MeResult({required this.accountId, required this.handle});
  factory MeResult.fromJson(Map<String, dynamic> j) => MeResult(
        accountId: j['account_id'] as String,
        handle: j['handle'] as String,
      );
  final String accountId;
  final String handle;
}

class ConversationDto {
  ConversationDto({
    required this.id,
    required this.peerAccountId,
    required this.title,
    required this.lastActiveAt,
    required this.preview,
  });
  factory ConversationDto.fromJson(Map<String, dynamic> j) => ConversationDto(
        id: j['id'] as String,
        peerAccountId: j['peer_account_id'] as String,
        title: j['title'] as String? ?? '',
        lastActiveAt: DateTime.parse(j['last_active_at'] as String),
        preview: j['last_message_preview'] as String? ?? '',
      );
  final String id;
  final String peerAccountId;
  final String title;
  final DateTime lastActiveAt;
  final String preview;
}

class MessageDto {
  MessageDto({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.ciphertext,
    required this.sentAt,
  });
  factory MessageDto.fromJson(Map<String, dynamic> j) => MessageDto(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        senderId: j['sender_id'] as String,
        kind: j['kind'] as String? ?? 'text',
        ciphertext: base64.decode(j['ciphertext_b64'] as String),
        sentAt: DateTime.parse(j['sent_at'] as String),
      );
  final String id;
  final String conversationId;
  final String senderId;
  final String kind;
  final Uint8List ciphertext;
  final DateTime sentAt;
}

// =====================================================================
// Pure-Dart SHA-256 implementation (FIPS 180-4). Used by hmacSha256.
// Standalone so the alpha client adds no extra dependency.
// =====================================================================

const List<int> _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

Uint8List _sha256(Uint8List msg) {
  // Pre-processing: pad to 512-bit blocks, append length.
  final bitLen = msg.length * 8;
  final padLen = ((msg.length + 9) % 64 == 0) ? 0 : (64 - ((msg.length + 9) % 64));
  final total = msg.length + 1 + padLen + 8;
  final padded = Uint8List(total)..setRange(0, msg.length, msg);
  padded[msg.length] = 0x80;
  // 64-bit big-endian length at the end.
  for (var i = 0; i < 8; i++) {
    padded[total - 1 - i] = (bitLen >> (8 * i)) & 0xff;
  }

  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;

  final w = List<int>.filled(64, 0);
  for (var off = 0; off < total; off += 64) {
    for (var i = 0; i < 16; i++) {
      final j = off + i * 4;
      w[i] = ((padded[j] & 0xff) << 24) |
          ((padded[j + 1] & 0xff) << 16) |
          ((padded[j + 2] & 0xff) << 8) |
          (padded[j + 3] & 0xff);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _ror(w[i - 15], 7) ^ _ror(w[i - 15], 18) ^ (_lsr(w[i - 15], 3));
      final s1 = _ror(w[i - 2], 17) ^ _ror(w[i - 2], 19) ^ (_lsr(w[i - 2], 10));
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h0,
        b = h1,
        c = h2,
        d = h3,
        e = h4,
        f = h5,
        g = h6,
        hh = h7;
    for (var i = 0; i < 64; i++) {
      final s1 = _ror(e, 6) ^ _ror(e, 11) ^ _ror(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final temp1 = (hh + s1 + ch + _k[i] + w[i]) & 0xffffffff;
      final s0 = _ror(a, 2) ^ _ror(a, 13) ^ _ror(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + hh) & 0xffffffff;
  }

  final out = Uint8List(32);
  void writeWord(int word, int offset) {
    out[offset] = (word >> 24) & 0xff;
    out[offset + 1] = (word >> 16) & 0xff;
    out[offset + 2] = (word >> 8) & 0xff;
    out[offset + 3] = word & 0xff;
  }
  writeWord(h0, 0);
  writeWord(h1, 4);
  writeWord(h2, 8);
  writeWord(h3, 12);
  writeWord(h4, 16);
  writeWord(h5, 20);
  writeWord(h6, 24);
  writeWord(h7, 28);
  return out;
}

int _ror(int x, int n) {
  x &= 0xffffffff;
  return ((x >> n) | (x << (32 - n))) & 0xffffffff;
}

int _lsr(int x, int n) => (x & 0xffffffff) >> n;

Uint8List _concat(List<Uint8List> parts) {
  var len = 0;
  for (final p in parts) {
    len += p.length;
  }
  final out = Uint8List(len);
  var off = 0;
  for (final p in parts) {
    out.setRange(off, off + p.length, p);
    off += p.length;
  }
  return out;
}
