/// Notification service abstraction.
abstract class NotificationService {
  Future<void> initialize();
  Future<String?> getToken();
  Future<void> showLocal({required String title, required String body, String? payload});
  Future<void> cancelAll();
  Future<void> setBadgeCount(int count);
}
