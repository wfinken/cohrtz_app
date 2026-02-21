import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/app/main_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_services.dart';

Future<void> pumpMainAppHarness(
  WidgetTester tester, {
  List<Map<String, String?>> knownGroups = const <Map<String, String?>>[],
  String? activeRoomName,
  bool connected = false,
}) async {
  SharedPreferences.setMockInitialValues({});

  final syncService = TestSyncService(
    knownGroups: knownGroups,
    activeRoomName: activeRoomName,
    connected: connected || knownGroups.isNotEmpty,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncServiceProvider.overrideWith(
          () => TestSyncServiceNotifier(syncService),
        ),
        groupConnectionProcessProvider.overrideWithValue(
          const FakeGroupConnectionProcess(),
        ),
        activityNotificationBootstrapProvider.overrideWith((ref) {}),
      ],
      child: const MainApp(),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
