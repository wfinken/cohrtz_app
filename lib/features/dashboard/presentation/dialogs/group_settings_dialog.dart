import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/system_model.dart';

class GroupSettingsDialog extends ConsumerStatefulWidget {
  const GroupSettingsDialog({super.key});

  @override
  ConsumerState<GroupSettingsDialog> createState() =>
      _GroupSettingsDialogState();
}

class _GroupSettingsDialogState extends ConsumerState<GroupSettingsDialog> {
  GroupType _selectedType = GroupType.family;
  late TextEditingController _nameController;

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;

    // Use higher precision for larger units to show small changes
    var precision = i > 1 ? 2 : 1;
    var s = (bytes / (1 << (i * 10))).toStringAsFixed(precision);
    return '$s ${suffixes[i]}';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'My Group');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We watch the settings to initialize/update the dropdown value
    final settingsAsync = ref.watch(groupSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        return _buildDialogContent(context, settings);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildDialogContent(context, null), // Fallback
    );
  }

  Widget _buildDialogContent(
    BuildContext context,
    GroupSettings? currentSettings,
  ) {
    // Initialize selection if it's the first build and we have settings
    // This is a bit hacky in build, but since we have a loading state, it's safer.
    // Actually, let's just use a local state that defaults to currentSettings?.groupType ?? GroupType.family.
    // But we need to do this only once.
    // Let's do it with a `_initialized` flag.
    if (!_initialized && currentSettings != null) {
      _selectedType = currentSettings.groupType;
      _nameController.text = currentSettings.name;
      _initialized = true;
    }

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
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
                  'Group Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Group Type',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<GroupType>(
                  value: _selectedType,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).cardColor,
                  items: GroupType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.displayName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
              ),
            ),
            Text(
              _getTypeDescription(_selectedType),
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Local Storage',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Consumer(
                  builder: (context, ref, child) {
                    final roomName =
                        ref.watch(
                          syncServiceProvider.select((s) => s.currentRoomName),
                        ) ??
                        '';
                    debugPrint(
                      '[GroupSettingsDialog] Local Storage Consumer rebuilding for $roomName',
                    );
                    final storageAsync = ref.watch(
                      roomStorageBreakdownProvider(roomName),
                    );

                    return storageAsync.when(
                      data: (breakdown) => Text(
                        _formatSize(breakdown.totalBytes),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      loading: () => const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (e, s) => Text(
                        '0 B',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Text(
              'Space used by this group on your device.',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                final roomName =
                    ref.watch(
                      syncServiceProvider.select((s) => s.currentRoomName),
                    ) ??
                    '';
                final storageAsync = ref.watch(
                  roomStorageBreakdownProvider(roomName),
                );

                return storageAsync.when(
                  data: (breakdown) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStorageBreakdownRow(
                        context,
                        'CRDT Database',
                        breakdown.crdtBytes,
                      ),
                      _buildStorageBreakdownRow(
                        context,
                        'Dashboard Layout',
                        breakdown.dashboardBytes,
                      ),
                      _buildStorageBreakdownRow(
                        context,
                        'Vault Packet Store',
                        breakdown.packetStoreBytes,
                      ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 8),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _saveSettings(context, currentSettings),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _initialized = false;

  Widget _buildStorageBreakdownRow(
    BuildContext context,
    String label,
    int bytes,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            _formatSize(bytes),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeDescription(GroupType type) {
    switch (type) {
      case GroupType.family:
        return 'Standard setup with Calendar, Vault, and Chores.';
      case GroupType.team:
        return 'Produvtivity focused with Schedule, Vault, and Tasks.';
      case GroupType.guild:
        return 'Gaming focused with Events, Treasury, and Quests.';
      case GroupType.apartment:
        return 'Living arrangements with Reservations, Info, and Maintenance.';
    }
  }

  Future<void> _saveSettings(
    BuildContext context,
    GroupSettings? currentSettings,
  ) async {
    try {
      final repo = ref.read(dashboardRepositoryProvider);
      final localOwnerId =
          ref.read(syncServiceProvider).identity ??
          ref.read(identityServiceProvider).profile?.id ??
          '';

      final newSettings =
          currentSettings?.copyWith(
            groupType: _selectedType,
            name: _nameController.text,
            dataRoomName: currentSettings.dataRoomName,
            invites: currentSettings.invites,
          ) ??
          GroupSettings(
            id: 'group_settings',
            name: _nameController.text.isEmpty
                ? 'My Group'
                : _nameController.text,
            createdAt: ref
                .read(hybridTimeServiceProvider)
                .getAdjustedTimeLocal(),
            logicalTime: ref.read(hybridTimeServiceProvider).nextLogicalTime(),
            groupType: _selectedType,
            dataRoomName: const Uuid().v4(),
            ownerId: localOwnerId,
          );

      final navigator = Navigator.of(context);
      await repo.saveGroupSettings(newSettings);

      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      debugPrint('[GroupSettingsDialog] Error saving settings: $e');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }
}
