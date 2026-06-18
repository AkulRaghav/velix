/// Environment configuration for different build modes.
enum AppEnvironment { development, staging, production }

class AppConfig {
  AppConfig._();

  static AppEnvironment get current {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return switch (env) {
      'production' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };
  }

  static bool get isDev => current == AppEnvironment.development;
  static bool get isProd => current == AppEnvironment.production;

  static String get apiBaseUrl => switch (current) {
    AppEnvironment.production => 'https://api.velix.app',
    AppEnvironment.staging => 'https://staging.api.velix.app',
    AppEnvironment.development => const String.fromEnvironment(
      'VELIX_ALPHA_URL', defaultValue: 'http://127.0.0.1:8080'),
  };
}
