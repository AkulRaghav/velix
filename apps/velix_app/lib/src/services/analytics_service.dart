/// Privacy-first analytics — no PII, local aggregation only.
abstract class AnalyticsService {
  void trackScreen(String name);
  void trackEvent(String name, {Map<String, dynamic>? params});
  void trackTiming(String category, String variable, Duration duration);
  Future<void> flush();
}
