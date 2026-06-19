/// Logger utility for structured debug output.
/// In production builds, calls are tree-shaken away via assert().
class VelixLogger {
  VelixLogger._();

  static void info(String tag, String message) {
    assert(() {
      // ignore: avoid_print
      print('[$tag] $message');
      return true;
    }());
  }

  static void error(String tag, String message, [Object? error]) {
    assert(() {
      // ignore: avoid_print
      print('[$tag ERROR] $message');
      if (error != null) {
        // ignore: avoid_print
        print('  -> $error');
      }
      return true;
    }());
  }

  static void network(String method, String url, int statusCode, Duration duration) {
    assert(() {
      // ignore: avoid_print
      print('[NET] $method $url -> $statusCode (${duration.inMilliseconds}ms)');
      return true;
    }());
  }
}
