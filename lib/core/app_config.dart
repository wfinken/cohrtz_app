/// Centralized application configuration.
/// Contains environment-specific values like API URLs and hardcoded constants.
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  static const String backendBaseUrl = 'https://r.cohrtz.com';

  static const String livekitUrl = 'wss://livekit.cohrtz.com';
  static const String defaultStunUrl = 'stun:stun.l.google.com:19302';
  static const bool enableBackgroundService = bool.fromEnvironment(
    'COHRTZ_BG_SERVICE',
    defaultValue: false,
  );

  static String getTokenUrl(String room, String identity) =>
      '$backendBaseUrl/token?room=$room&identity=$identity';
}
