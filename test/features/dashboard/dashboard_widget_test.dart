import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/features/dashboard/domain/dashboard_models.dart';
import 'package:cohortz/core/utils/extensions.dart';

void main() {
  group('DashboardWidget Add Functionality', () {
    test('allTypes contains all expected widgets', () {
      expect(
        DashboardWidget.allTypes,
        containsAll([
          'calendar',
          'vault',
          'tasks',
          'notes',
          'users',
          'chat',
          'polls',
        ]),
      );
    });

    test('getFriendlyName returns correct names', () {
      expect(DashboardWidget.getFriendlyName('calendar'), 'Calendar');
      expect(DashboardWidget.getFriendlyName('vault'), 'Vault');
      expect(DashboardWidget.getFriendlyName('tasks'), 'Tasks');
      expect(DashboardWidget.getFriendlyName('notes'), 'Notes');
      expect(DashboardWidget.getFriendlyName('users'), 'Members');
      expect(DashboardWidget.getFriendlyName('chat'), 'Channels');
      expect(DashboardWidget.getFriendlyName('polls'), 'Polls');
      expect(DashboardWidget.getFriendlyName('unknown'), 'Unknown');
    });

    test('StringExtension.toTitleCase works correctly', () {
      expect('hello world'.toTitleCase(), 'Hello World');
      expect('DASHBOARD'.toTitleCase(), 'Dashboard');
      expect(''.toTitleCase(), '');
    });
  });
}
