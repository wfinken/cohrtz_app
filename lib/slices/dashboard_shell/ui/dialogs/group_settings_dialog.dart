import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cohortz/shared/profile/avatar_picker_service.dart';
import 'package:cohortz/shared/profile/avatar_processing_service.dart';
import 'package:cohortz/shared/profile/profile_constants.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';

import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';

class GroupSettingsDialog extends ConsumerStatefulWidget {
  const GroupSettingsDialog({super.key});

  @override
  ConsumerState<GroupSettingsDialog> createState() =>
      _GroupSettingsDialogState();
}

class _GroupSettingsDialogState extends ConsumerState<GroupSettingsDialog> {
  GroupType _selectedType = GroupType.family;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String _avatarBase64 = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'My Group');
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
      _descriptionController.text = currentSettings.description;
      _avatarBase64 = currentSettings.avatarBase64;
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
            Row(
              children: [
                ProfileAvatar(
                  displayName: _nameController.text.trim().isEmpty
                      ? 'Group'
                      : _nameController.text.trim(),
                  avatarBase64: _avatarBase64,
                  fallbackIcon: Icons.groups_2_outlined,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saving ? null : () => _pickAvatar(context),
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _avatarBase64.trim().isEmpty
                              ? 'Upload Avatar'
                              : 'Change Avatar',
                        ),
                      ),
                      if (_avatarBase64.trim().isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _avatarBase64 = ''),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Group Name',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLength: kGroupDescriptionMaxLength,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Tell members what this group is for',
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
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () => _saveSettings(context, currentSettings),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _initialized = false;

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

  Future<void> _pickAvatar(BuildContext context) async {
    try {
      final result = await AvatarPickerService.pickCropAndProcessAvatar(
        context,
      );
      if (result == null || !mounted) return;
      setState(() => _avatarBase64 = result.base64Data);
    } on AvatarTooLargeException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image is still too large after compression. Please choose a simpler image.',
          ),
        ),
      );
    } on AvatarDecodeException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that image file.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to process avatar: $e')));
    }
  }

  Future<void> _saveSettings(
    BuildContext context,
    GroupSettings? currentSettings,
  ) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(dashboardRepositoryProvider);
      final localOwnerId = ref.read(syncServiceProvider).identity ?? '';
      final normalizedName = _nameController.text.trim().isEmpty
          ? 'My Group'
          : _nameController.text.trim();
      final normalizedDescription = _descriptionController.text.trim();

      final newSettings =
          currentSettings?.copyWith(
            groupType: _selectedType,
            name: normalizedName,
            description: normalizedDescription,
            avatarBase64: _avatarBase64,
            dataRoomName: currentSettings.dataRoomName,
            invites: currentSettings.invites,
          ) ??
          GroupSettings(
            id: 'group_settings',
            name: normalizedName,
            description: normalizedDescription,
            avatarBase64: _avatarBase64,
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
        setState(() => _saving = false);
      }
    }
  }
}
