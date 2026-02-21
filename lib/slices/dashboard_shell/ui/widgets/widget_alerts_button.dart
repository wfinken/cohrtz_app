import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../dialogs/widget_alerts_dialog.dart';

class WidgetAlertsButton extends ConsumerWidget {
  final String groupId;
  final String widgetType;
  final String widgetTitle;

  final double iconSize;
  final BoxConstraints constraints;

  const WidgetAlertsButton({
    super.key,
    required this.groupId,
    required this.widgetType,
    required this.widgetTitle,
    this.iconSize = 18,
    this.constraints = const BoxConstraints.tightFor(width: 32, height: 32),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (widgetType.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final enabledAsync = ref.watch(
      widgetNotificationsEnabledProvider((
        groupId: groupId,
        widgetType: widgetType,
      )),
    );
    final enabled = enabledAsync.value ?? true;

    return IconButton(
      tooltip: enabled ? 'Widget notifications on' : 'Widget notifications off',
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => WidgetAlertsDialog(
            groupId: groupId,
            widgetType: widgetType,
            widgetTitle: widgetTitle,
          ),
        );
      },
      icon: Icon(
        enabled
            ? Icons.notifications_outlined
            : Icons.notifications_off_outlined,
        size: iconSize,
        color: enabled ? theme.hintColor : theme.colorScheme.primary,
      ),
      padding: EdgeInsets.zero,
      constraints: constraints,
      visualDensity: VisualDensity.compact,
    );
  }
}
