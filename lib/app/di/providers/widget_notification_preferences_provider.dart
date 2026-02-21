import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/slices/notifications/widget_notification_preferences.dart';

final widgetNotificationPreferencesProvider =
    Provider<WidgetNotificationPreferences>((ref) {
      final prefs = WidgetNotificationPreferences();
      ref.onDispose(prefs.dispose);
      return prefs;
    });

final widgetNotificationsEnabledProvider =
    StreamProvider.family<bool, ({String groupId, String widgetType})>((
      ref,
      args,
    ) {
      final prefs = ref.watch(widgetNotificationPreferencesProvider);
      return prefs.watchEnabled(
        groupId: args.groupId,
        widgetType: args.widgetType,
      );
    });
