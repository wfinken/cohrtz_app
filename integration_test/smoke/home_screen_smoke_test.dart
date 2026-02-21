import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/test_app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots the app and shows an empty-state shell', (
    WidgetTester tester,
  ) async {
    await pumpMainAppHarness(tester);

    expect(find.text('No groups!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
