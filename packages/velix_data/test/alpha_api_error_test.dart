import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:velix_data/velix_data.dart';

/// Verifies that AlphaApiClient surfaces non-2xx responses as
/// AlphaApiException carrying the server-provided error message.
void main() {
  late HttpServer server;

  Future<HttpServer> startServer({
    required int statusCode,
    required Map<String, dynamic> body,
  }) async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    s.listen((req) async {
      req.response.statusCode = statusCode;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(body));
      await req.response.close();
    });
    return s;
  }

  tearDown(() async {
    await server.close(force: true);
  });

  test('register surfaces 409 conflict', () async {
    server = await startServer(
      statusCode: 409,
      body: {'error': 'handle taken'},
    );
    final client = AlphaApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );
    addTearDown(client.close);

    try {
      await client.register(
        handle: 'alice',
        deviceSecret: AlphaApiClient.generateDeviceSecret(),
      );
      fail('expected AlphaApiException');
    } on AlphaApiException catch (e) {
      expect(e.statusCode, 409);
      expect(e.message, contains('handle taken'));
    }
  });

  test('me surfaces 401 unauthorized', () async {
    server = await startServer(
      statusCode: 401,
      body: {'error': 'invalid or expired token'},
    );
    final client = AlphaApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );
    client.token = 'bogus';
    addTearDown(client.close);

    try {
      await client.me();
      fail('expected AlphaApiException');
    } on AlphaApiException catch (e) {
      expect(e.statusCode, 401);
      expect(e.message, contains('invalid'));
    }
  });

  test('lookup surfaces 500 with default message when error field is absent',
      () async {
    server = await startServer(statusCode: 500, body: const {});
    final client = AlphaApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );
    client.token = 'fake';
    addTearDown(client.close);

    try {
      await client.lookup(handle: 'bob');
      fail('expected AlphaApiException');
    } on AlphaApiException catch (e) {
      expect(e.statusCode, 500);
      expect(e.message, contains('http 500'));
    }
  });
}
