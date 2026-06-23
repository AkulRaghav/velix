/// Constants for the Velix app used across screens.
class AppConstants {
  AppConstants._();

  static const String appName = 'Velix';
  static const String tagline = 'Private messaging, reimagined';

  // Polling intervals
  static const Duration conversationPollInterval = Duration(seconds: 3);
  static const Duration messagePollInterval = Duration(seconds: 2);
  static const Duration presencePollInterval = Duration(seconds: 10);

  // Limits
  static const int maxMessageLength = 4096;
  static const int maxHandleLength = 32;
  static const int minHandleLength = 3;
  static const int maxConversationTitleLength = 64;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);

  // API
  static const Duration apiTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
}
