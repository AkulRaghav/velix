import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:velix_data/velix_data.dart';

/// Verifies that the polling timer stops when the last watcher detaches.
void main() {
  test('stops polling after the last watcher cancels', () async {
    var requestCount = 0;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/v1/conversations') {
        requestCount++;
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'conversations': <dynamic>[]}));
      await req.response.close();
    });

    final client = AlphaApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );
    client.token = 'fake-token';

    final repo = RemoteConversationRepository(
      client: client,
      myAccountId: 'me',
      pollInterval: const Duration(milliseconds: 50),
    );

    // Subscribe.
    final sub = repo.watchAll().listen((_) {});

    // Allow a few polls to fire.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final countWhileSubscribed = requestCount;
    expect(countWhileSubscribed, greaterThanOrEqualTo(2),
        reason: 'expected at least 2 polls while subscribed');

    // Unsubscribe.
    await sub.cancel();

    // Wait beyond several poll intervals.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final countAfterUnsub = requestCount;
    expect(countAfterUnsub - countWhileSubscribed, lessThanOrEqualTo(1),
        reason:
            'expected polling to stop after unsubscribe (allowing at most one in-flight request)');

    repo.dispose();
    client.close();
    await server.close(force: true);
  });
}
