import 'package:cohortz/slices/dashboard_shell/ui/widgets/group_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/test_app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders known groups and updates active group title', (
    WidgetTester tester,
  ) async {
    await pumpMainAppHarness(
      tester,
      knownGroups: const <Map<String, String?>>[
        {'roomName': 'room-1', 'friendlyName': 'Group One'},
        {'roomName': 'room-2', 'friendlyName': 'Group Two'},
      ],
      activeRoomName: 'room-1',
      connected: true,
    );

    expect(find.byType(GroupButton), findsNWidgets(2));
    expect(find.text('Group One'), findsOneWidget);

    await tester.tap(find.byType(GroupButton).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Group Two'), findsOneWidget);
  });
}
