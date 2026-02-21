import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';

class AppSettingsDialog extends ConsumerStatefulWidget {
  const AppSettingsDialog({super.key});

  @override
  ConsumerState<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends ConsumerState<AppSettingsDialog> {
  GroupNotificationSettings _notificationSettings =
      const GroupNotificationSettings();
  bool _initialized = false;
  String? _lastUserKey;
  String? _lastSettingsId;

  String _resolveUserKey() {
    final syncId = ref.read(syncServiceProvider).identity;
    final profileId = ref.read(identityServiceProvider).profile?.id;
    final resolved = syncId ?? profileId ?? '';
    return resolved.isEmpty ? 'default' : resolved;
  }

  GroupSettings _resolveSettings(GroupSettings? currentSettings) {
    if (currentSettings != null) return currentSettings;
    final syncService = ref.read(syncServiceProvider);
    final roomName = syncService.currentRoomName ?? '';
    final time = ref.read(hybridTimeServiceProvider);
    return GroupSettings(
      id: 'group_settings',
      name: syncService.getFriendlyName(roomName),
      createdAt: time.getAdjustedTimeLocal(),
      logicalTime: time.nextLogicalTime(),
      dataRoomName: roomName,
      ownerId:
          syncService.identity ??
          ref.read(identityServiceProvider).profile?.id ??
          '',
    );
  }

  Future<void> _saveNotificationSettings(
    GroupSettings currentSettings,
    String userKey,
    GroupNotificationSettings settings,
  ) async {
    final repo = ref.read(dashboardRepositoryProvider);
    final updatedMap = {
      ...currentSettings.notificationSettingsByUser,
      userKey: settings,
    };
    await repo.saveGroupSettings(
      currentSettings.copyWith(notificationSettingsByUser: updatedMap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final groupSettingsAsync = ref.watch(groupSettingsProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 8),
          Text(
            'App Settings',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  activeThumbColor: Colors.blue,
                  activeTrackColor: Colors.blue.withValues(alpha: 0.2),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  onChanged: (value) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
              const Divider(),
              groupSettingsAsync.when(
                data: (settings) {
                  final resolvedSettings = _resolveSettings(settings);
                  final userKey = _resolveUserKey();
                  if (!_initialized ||
                      _lastUserKey != userKey ||
                      _lastSettingsId != resolvedSettings.id) {
                    _notificationSettings = resolvedSettings.settingsForUser(
                      userKey == 'default' ? '' : userKey,
                    );
                    _initialized = true;
                    _lastUserKey = userKey;
                    _lastSettingsId = resolvedSettings.id;
                  }

                  final groupLabel = resolvedSettings.name.isEmpty
                      ? 'This Group'
                      : resolvedSettings.name;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications for $groupLabel',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'All Notifications',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Master switch for all notifications in this group.',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                        value: _notificationSettings.allNotifications,
                        onChanged: (value) async {
                          final next = _notificationSettings.withAll(value);
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'New Tasks',
                        subtitle: 'When someone adds a task to this group.',
                        value: _notificationSettings.newTasks,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            newTasks: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Task Completions',
                        subtitle: 'When tasks are marked complete.',
                        value: _notificationSettings.completedTasks,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            completedTasks: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Calendar Events',
                        subtitle: 'When new events are added.',
                        value: _notificationSettings.calendarEvents,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            calendarEvents: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Vault Items',
                        subtitle: 'When new items are stored.',
                        value: _notificationSettings.vaultItems,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            vaultItems: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Chat Messages',
                        subtitle: 'When someone posts a new message.',
                        value: _notificationSettings.chatMessages,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            chatMessages: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'New Polls',
                        subtitle: 'When a new poll is created.',
                        value: _notificationSettings.newPolls,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            newPolls: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Poll Results',
                        subtitle: 'When polls close or expire.',
                        value: _notificationSettings.closedPolls,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            closedPolls: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Poll Votes',
                        subtitle: 'When new votes are cast.',
                        value: _notificationSettings.pollVotes,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            pollVotes: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Members Joining',
                        subtitle: 'When someone joins this group.',
                        value: _notificationSettings.memberJoined,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            memberJoined: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                      _buildNotificationToggle(
                        context,
                        title: 'Members Leaving',
                        subtitle: 'When someone leaves this group.',
                        value: _notificationSettings.memberLeft,
                        onChanged: (value) async {
                          final next = _notificationSettings.copyWith(
                            memberLeft: value,
                          );
                          setState(() {
                            _notificationSettings = next;
                          });
                          await _saveNotificationSettings(
                            resolvedSettings,
                            userKey,
                            next,
                          );
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Unable to load notification settings.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildNotificationToggle(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
      ),
      activeThumbColor: Theme.of(context).colorScheme.primary,
      activeTrackColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.3),
    );
  }
}
