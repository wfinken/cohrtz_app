const bool _e2eEnabled = bool.fromEnvironment(
  'COHRTZ_E2E_ENABLED',
  defaultValue: false,
);
const int _e2eUserCount = int.fromEnvironment(
  'COHRTZ_E2E_USER_COUNT',
  defaultValue: 0,
);
const String _e2eRoomPrefix = String.fromEnvironment(
  'COHRTZ_E2E_ROOM_PREFIX',
  defaultValue: 'cohrtz-e2e',
);

class E2eEnvConfig {
  const E2eEnvConfig({
    required this.enabled,
    required this.userCount,
    required this.roomPrefix,
  });

  final bool enabled;
  final int userCount;
  final String roomPrefix;

  static const String runCommand =
      'flutter test integration_test/e2e/two_client_smoke_test.dart '
      '--dart-define=COHRTZ_E2E_ENABLED=true '
      '--dart-define=COHRTZ_E2E_USER_COUNT=<count> '
      '[--dart-define=COHRTZ_E2E_ROOM_PREFIX=<prefix>]';

  static const E2eEnvConfig fromEnvironment = E2eEnvConfig(
    enabled: _e2eEnabled,
    userCount: _e2eUserCount,
    roomPrefix: _e2eRoomPrefix,
  );

  bool get shouldSkip => !enabled || userCount < 2;

  String get skipReason {
    if (!enabled) {
      return 'missing COHRTZ_E2E_ENABLED=true';
    }
    if (userCount < 2) {
      return 'COHRTZ_E2E_USER_COUNT must be >= 2';
    }
    return 'unknown';
  }
}
