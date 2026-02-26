import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';

import '../../../../shared/theme/tokens/app_shape_tokens.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';

class NotificationSettingsDialog extends ConsumerStatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  ConsumerState<NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _GroupOption {
  final String roomId;
  final String label;

  const _GroupOption({required this.roomId, required this.label});
}

class _NotificationSettingsDialogState
    extends ConsumerState<NotificationSettingsDialog> {
  String? _selectedRoomId;
  bool _loadingGroups = true;
  List<_GroupOption> _groups = [];
  GroupNotificationSettings _notificationSettings =
      const GroupNotificationSettings();
  String? _lastUserKey;
  String? _lastSettingsId;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groupManager = ref.read(groupManagerProvider);
    final knownGroups = await groupManager.getKnownGroups();
    final options = <_GroupOption>[];

    for (final group in knownGroups) {
      final roomId = group['dataRoomName'] ?? group['roomName'] ?? '';
      if (roomId.isEmpty) continue;
      final label = group['friendlyName'] ?? group['roomName'] ?? 'Group';
      options.add(_GroupOption(roomId: roomId, label: label));
    }

    if (options.isEmpty) {
      final currentRoom = ref.read(dashboardRepositoryProvider).currentRoomName;
      if (currentRoom != null && currentRoom.isNotEmpty) {
        options.add(
          _GroupOption(
            roomId: currentRoom,
            label: ref.read(syncServiceProvider).getFriendlyName(currentRoom),
          ),
        );
      }
    }

    final currentRoom = ref.read(dashboardRepositoryProvider).currentRoomName;
    final defaultRoom = options.any((g) => g.roomId == currentRoom)
        ? currentRoom
        : (options.isNotEmpty ? options.first.roomId : null);

    if (mounted) {
      setState(() {
        _groups = options;
        _selectedRoomId = defaultRoom;
        _loadingGroups = false;
      });
    }
  }

  String _resolveUserKey() {
    final syncId = ref.read(syncServiceProvider).identity;
    final resolved = syncId ?? '';
    return resolved.isEmpty ? 'default' : resolved;
  }

  GroupSettings _resolveSettings(
    String roomId,
    GroupSettings? currentSettings,
  ) {
    if (currentSettings != null) return currentSettings;
    final syncService = ref.read(syncServiceProvider);
    final time = ref.read(hybridTimeServiceProvider);
    return GroupSettings(
      id: 'group_settings',
      name: syncService.getFriendlyName(roomId),
      createdAt: time.getAdjustedTimeLocal(),
      logicalTime: time.nextLogicalTime(),
      dataRoomName: roomId,
      ownerId: syncService.identity ?? '',
    );
  }

  Future<void> _saveNotificationSettings(
    DashboardRepository repo,
    GroupSettings currentSettings,
    String userKey,
    GroupNotificationSettings settings,
  ) async {
    final updatedMap = {
      ...currentSettings.notificationSettingsByUser,
      userKey: settings,
    };
    await repo.saveGroupSettings(
      currentSettings.copyWith(notificationSettingsByUser: updatedMap),
    );
  }

  GroupNotificationSettings _syncAllFlag(GroupNotificationSettings settings) {
    final allEnabled =
        settings.newTasks &&
        settings.completedTasks &&
        settings.calendarEvents &&
        settings.vaultItems &&
        settings.chatMessages &&
        settings.newPolls &&
        settings.closedPolls &&
        settings.pollVotes &&
        settings.memberJoined &&
        settings.memberLeft;
    return settings.copyWith(allNotifications: allEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: context.appBorderRadius()),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 460),
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
                      Icons.notifications_active,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Notification Settings',
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
                'Server',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingGroups)
                const Center(child: CircularProgressIndicator())
              else if (_groups.isEmpty)
                Text(
                  'No servers available.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedRoomId),
                  initialValue: _selectedRoomId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.appRadius()),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: _groups
                      .map(
                        (group) => DropdownMenuItem<String>(
                          value: group.roomId,
                          child: Text(group.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedRoomId = value;
                    });
                  },
                ),
              const SizedBox(height: 16),
              if (_selectedRoomId != null)
                _buildNotificationControls(context, _selectedRoomId!),
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

  Widget _buildNotificationControls(BuildContext context, String roomId) {
    final repo = DashboardRepository(
      ref.read(crdtServiceProvider),
      roomId,
      ref.read(hybridTimeServiceProvider),
    );

    return StreamBuilder<GroupSettings?>(
      stream: repo.watchGroupSettings(),
      builder: (context, snapshot) {
        final settings = _resolveSettings(roomId, snapshot.data);
        final userKey = _resolveUserKey();
        if (_lastUserKey != userKey || _lastSettingsId != settings.id) {
          _notificationSettings = settings.settingsForUser(
            userKey == 'default' ? '' : userKey,
          );
          _lastUserKey = userKey;
          _lastSettingsId = settings.id;
        }

        final groupLabel = settings.name.isEmpty
            ? 'This Server'
            : settings.name;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications for $groupLabel',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
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
                'Master switch for all notifications in this server.',
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
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
              activeThumbColor: Theme.of(context).colorScheme.primary,
              activeTrackColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
            _buildNotificationToggle(
              context,
              title: 'New Tasks',
              subtitle: 'When someone adds a task to this server.',
              value: _notificationSettings.newTasks,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(newTasks: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Task Completions',
              subtitle: 'When tasks are marked complete.',
              value: _notificationSettings.completedTasks,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(completedTasks: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Calendar Events',
              subtitle: 'When new events are added.',
              value: _notificationSettings.calendarEvents,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(calendarEvents: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Vault Items',
              subtitle: 'When new items are stored.',
              value: _notificationSettings.vaultItems,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(vaultItems: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Chat Messages',
              subtitle: 'When someone posts a new message.',
              value: _notificationSettings.chatMessages,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(chatMessages: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'New Polls',
              subtitle: 'When a new poll is created.',
              value: _notificationSettings.newPolls,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(newPolls: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Poll Results',
              subtitle: 'When polls close or expire.',
              value: _notificationSettings.closedPolls,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(closedPolls: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Poll Votes',
              subtitle: 'When new votes are cast.',
              value: _notificationSettings.pollVotes,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(pollVotes: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Members Joining',
              subtitle: 'When someone joins this server.',
              value: _notificationSettings.memberJoined,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(memberJoined: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
            _buildNotificationToggle(
              context,
              title: 'Members Leaving',
              subtitle: 'When someone leaves this server.',
              value: _notificationSettings.memberLeft,
              onChanged: (value) async {
                final next = _syncAllFlag(
                  _notificationSettings.copyWith(memberLeft: value),
                );
                setState(() {
                  _notificationSettings = next;
                });
                await _saveNotificationSettings(repo, settings, userKey, next);
              },
            ),
          ],
        );
      },
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
