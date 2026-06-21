/// Network connectivity checker for offline-first behavior.
import 'dart:async';
import 'dart:io';

class ConnectivityService {
  ConnectivityService._();

  /// Check if the backend is reachable.
  static Future<bool> isBackendReachable(Uri baseUri) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(baseUri.resolve('/v1/healthz'));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check general internet connectivity.
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('dns.google');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}
