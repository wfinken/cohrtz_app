import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/tokens/dialog_button_styles.dart';
import '../../../../shared/utils/debug_helper.dart';

import '../../../../app/di/app_providers.dart';
import 'notification_settings_dialog.dart';

class AppUserSettingsDialog extends ConsumerStatefulWidget {
  const AppUserSettingsDialog({super.key});

  @override
  ConsumerState<AppUserSettingsDialog> createState() =>
      _AppUserSettingsDialogState();
}

class _AppUserSettingsDialogState extends ConsumerState<AppUserSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'App Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'App Settings',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Theme',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('System'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Light'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                  ),
                ],
                selected: {themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(selection.first);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Notifications',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Choose a server and configure notification types.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).hintColor,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => const NotificationSettingsDialog(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 16),
              // DEBUG: Clear Data Button
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Clear App Data',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Debug only: Wipes all data and resets app',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Data?'),
                      content: const Text(
                        'This will delete all local data, keys, and databases. The app will close or need to be restarted manually. Are you sure?',
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: dialogDestructiveButtonStyle(context),
                          child: const Text('Clear Everything'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    // ignore: use_build_context_synchronously
                    await DebugHelper.clearAllData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Data cleared. Please restart the app.',
                          ),
                          duration: Duration(seconds: 5),
                        ),
                      );
                      await Future.delayed(const Duration(seconds: 2));
                      exit(0);
                    }
                  }
                },
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
