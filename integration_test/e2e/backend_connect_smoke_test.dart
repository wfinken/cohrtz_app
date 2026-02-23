import 'dart:convert';

import 'package:cohortz/app/bootstrap/app_bootstrap.dart';
import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/app/main_app.dart';
import 'package:cohortz/shared/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _e2eEnabled = bool.fromEnvironment(
  'COHRTZ_E2E_ENABLED',
  defaultValue: false,
);
const String _e2eRoom = String.fromEnvironment('COHRTZ_E2E_ROOM');
const String _e2eIdentity = String.fromEnvironment('COHRTZ_E2E_IDENTITY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final shouldSkip = !_e2eEnabled || _e2eRoom.isEmpty || _e2eIdentity.isEmpty;

  if (shouldSkip) {
    final reason = !_e2eEnabled
        ? 'missing COHRTZ_E2E_ENABLED=true'
        : _e2eRoom.isEmpty
        ? 'missing COHRTZ_E2E_ROOM'
        : 'missing COHRTZ_E2E_IDENTITY';
    // ignore: avoid_print
    print(
      'Skipping backend_connect_smoke_test.dart: $reason. '
      'Run with --dart-define=COHRTZ_E2E_ENABLED=true '
      '--dart-define=COHRTZ_E2E_ROOM=<room> '
      '--dart-define=COHRTZ_E2E_IDENTITY=<identity>.',
    );
  }

  testWidgets(
    'fetches token, connects to a backend room, then disconnects',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final appScope = await createAppProviderScope(
        child: const MainApp(),
        options: const AppBootstrapOptions(initializeBackgroundService: false),
      );

      await tester.pumpWidget(appScope);
      await tester.pump();

      final tokenUri = Uri.parse(AppConfig.getTokenUrl(_e2eRoom, _e2eIdentity));
      final tokenResponse = await http.get(tokenUri);

      expect(
        tokenResponse.statusCode,
        200,
        reason: 'Token fetch failed: ${tokenResponse.body}',
      );

      final body = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final token = body['token'] as String?;
      expect(token, isNotNull);
      expect(token, isNotEmpty);

      final context = tester.element(find.byType(MainApp));
      final container = ProviderScope.containerOf(context, listen: false);
      final syncService = container.read(syncServiceProvider);

      await syncService.connect(
        token!,
        _e2eRoom,
        identity: _e2eIdentity,
        friendlyName: _e2eRoom,
      );
      expect(syncService.isConnected, isTrue);

      await syncService.disconnect();
      expect(syncService.isConnected, isFalse);
    },
    skip: shouldSkip,
  );
}
