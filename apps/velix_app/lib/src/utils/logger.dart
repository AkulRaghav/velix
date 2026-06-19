/// Logger utility for structured debug output.
/// In production builds, calls are tree-shaken away.
class VelixLogger {
  VelixLogger._();

  static void info(String tag, String message) {
    assert(() {
      print('[\] \');
      return true;
    }());
  }

  static void error(String tag, String message, [Object? error]) {
    assert(() {
      print('[\ ERROR] \');
      if (error != null) print('  -> \A parameter cannot be found that matches parameter name 'Chord'. A parameter cannot be found that matches parameter name 'Chord'. A parameter cannot be found that matches parameter name 'Chord'. A parameter cannot be found that matches parameter name 'Chord'.');
      return true;
    }());
  }

  static void network(String method, String url, int statusCode, Duration duration) {
    assert(() {
      final ms = duration.inMilliseconds;
      print('[NET] \ \ -> \ (\ms)');
      return true;
    }());
  }
}
