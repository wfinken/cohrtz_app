const bool _e2eEnabled = bool.fromEnvironment(
  'COHRTZ_E2E_ENABLED',
  defaultValue: false,
);
const String _e2eRoom = String.fromEnvironment('COHRTZ_E2E_ROOM');
const String _e2eIdentityA = String.fromEnvironment('COHRTZ_E2E_IDENTITY_A');
const String _e2eIdentityB = String.fromEnvironment('COHRTZ_E2E_IDENTITY_B');

class E2eEnvConfig {
  const E2eEnvConfig({
    required this.enabled,
    required this.room,
    required this.identityA,
    required this.identityB,
  });

  final bool enabled;
  final String room;
  final String identityA;
  final String identityB;

  static const String runCommand =
      'flutter test integration_test/e2e/two_client_smoke_test.dart '
      '--dart-define=COHRTZ_E2E_ENABLED=true '
      '--dart-define=COHRTZ_E2E_ROOM=<room> '
      '--dart-define=COHRTZ_E2E_IDENTITY_A=<identity-a> '
      '--dart-define=COHRTZ_E2E_IDENTITY_B=<identity-b>';

  static const E2eEnvConfig fromEnvironment = E2eEnvConfig(
    enabled: _e2eEnabled,
    room: _e2eRoom,
    identityA: _e2eIdentityA,
    identityB: _e2eIdentityB,
  );

  bool get hasDistinctIdentities => identityA != identityB;

  bool get shouldSkip =>
      !enabled || room.isEmpty || identityA.isEmpty || identityB.isEmpty;

  String get skipReason {
    if (!enabled) {
      return 'missing COHRTZ_E2E_ENABLED=true';
    }
    if (room.isEmpty) {
      return 'missing COHRTZ_E2E_ROOM';
    }
    if (identityA.isEmpty) {
      return 'missing COHRTZ_E2E_IDENTITY_A';
    }
    if (identityB.isEmpty) {
      return 'missing COHRTZ_E2E_IDENTITY_B';
    }
    return 'unknown';
  }
}
