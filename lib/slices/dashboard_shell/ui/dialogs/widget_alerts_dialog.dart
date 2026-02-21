import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../shared/theme/tokens/app_theme.dart';

class WidgetAlertsDialog extends ConsumerWidget {
  final String groupId;
  final String widgetType;
  final String widgetTitle;

  const WidgetAlertsDialog({
    super.key,
    required this.groupId,
    required this.widgetType,
    required this.widgetTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabledAsync = ref.watch(
      widgetNotificationsEnabledProvider((
        groupId: groupId,
        widgetType: widgetType,
      )),
    );
    final enabled = enabledAsync.value ?? true;

    final containerColor = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
    );
    final containerBorderColor = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.28 : 0.16,
    );

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: containerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: containerBorderColor),
                    ),
                    child: Icon(
                      enabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Widget Alerts',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: theme.hintColor, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(AppTheme.elementRadius),
                  border: Border.all(color: containerBorderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enabled ? 'Notifications On' : 'Notifications Off',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'WIDGET PREFERENCE',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: enabled,
                      onChanged: (value) async {
                        await ref
                            .read(widgetNotificationPreferencesProvider)
                            .setEnabled(
                              groupId: groupId,
                              widgetType: widgetType,
                              enabled: value,
                            );
                      },
                      activeThumbColor: theme.colorScheme.primary,
                      activeTrackColor: theme.colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Settings apply only to this $widgetTitle widget',
                style: TextStyle(color: theme.hintColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
