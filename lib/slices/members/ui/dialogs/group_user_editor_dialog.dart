import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/shared/profile/avatar_picker_service.dart';
import 'package:cohortz/shared/profile/avatar_processing_service.dart';
import 'package:cohortz/shared/profile/profile_constants.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';

import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/app/di/app_providers.dart';

class GroupUserEditorDialog extends ConsumerStatefulWidget {
  const GroupUserEditorDialog({super.key, this.initialProfile});

  final UserProfile? initialProfile;

  @override
  ConsumerState<GroupUserEditorDialog> createState() =>
      _GroupUserEditorDialogState();
}

class _GroupUserEditorDialogState extends ConsumerState<GroupUserEditorDialog> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _roomName;
  String? _userId;
  String _publicKey = '';
  String _avatarBase64 = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final sync = ref.read(syncServiceProvider);
    final roomName = sync.currentRoomName;
    final userId = roomName == null
        ? null
        : (sync.getLocalParticipantIdForRoom(roomName) ?? sync.identity);
    if (roomName == null ||
        roomName.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No active group selected.';
      });
      return;
    }

    UserProfile? profile = widget.initialProfile;
    if (profile == null) {
      final profiles =
          ref.read(userProfilesProvider).value ?? const <UserProfile>[];
      for (final candidate in profiles) {
        if (candidate.id == userId) {
          profile = candidate;
          break;
        }
      }
    }

    if (profile == null) {
      final groupIdentity = ref.read(groupIdentityServiceProvider);
      profile = await groupIdentity.loadForGroup(roomName);
      if (profile == null) {
        final globalName = ref
            .read(identityServiceProvider)
            .profile
            ?.displayName
            .trim();
        profile = await groupIdentity.ensureForGroup(
          groupId: roomName,
          displayName: (globalName == null || globalName.isEmpty)
              ? null
              : globalName,
          fallbackIdentity: userId,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _roomName = roomName;
      _userId = profile!.id;
      _publicKey = profile.publicKey;
      _nameController.text = profile.displayName;
      _bioController.text = profile.bio;
      _avatarBase64 = profile.avatarBase64;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final roomName = _roomName;
    final userId = _userId;
    if (roomName == null || userId == null) return;

    setState(() => _saving = true);
    try {
      final normalizedName = _nameController.text.trim();
      final normalizedBio = _normalizeBio(_bioController.text);

      final profile = await ref
          .read(groupIdentityServiceProvider)
          .ensureForGroup(
            groupId: roomName,
            displayName: normalizedName,
            avatarBase64: _avatarBase64,
            bio: normalizedBio,
            fallbackIdentity: userId,
          );

      await ref.read(dashboardRepositoryProvider).saveUserProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _regenerateKeys() async {
    final roomName = _roomName;
    final userId = _userId;
    if (roomName == null || userId == null) return;

    setState(() => _saving = true);
    try {
      final normalizedBio = _normalizeBio(_bioController.text);
      final profile = await ref
          .read(groupIdentityServiceProvider)
          .regenerateKeysForGroup(
            groupId: roomName,
            displayName: _nameController.text.trim(),
            avatarBase64: _avatarBase64,
            bio: normalizedBio,
            fallbackIdentity: userId,
          );
      await ref.read(dashboardRepositoryProvider).saveUserProfile(profile);
      await ref
          .read(handshakeHandlerProvider)
          .broadcastHandshake(roomName, force: true);
      if (!mounted) return;
      setState(() {
        _publicKey = profile.publicKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group keys regenerated and profile synced.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to regenerate keys: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _normalizeBio(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length <= kUserBioMaxLength) return trimmed;
    return trimmed.substring(0, kUserBioMaxLength);
  }

  Future<void> _pickAvatar() async {
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
            'Image is still too large after compression. Please choose a different image.',
          ),
        ),
      );
    } on AvatarDecodeException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not decode selected image.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar processing failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Group Profile',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ProfileAvatar(
                  displayName: _nameController.text.trim().isEmpty
                      ? 'User'
                      : _nameController.text.trim(),
                  avatarBase64: _avatarBase64,
                  size: 62,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _pickAvatar,
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
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Name visible in this group',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLength: kUserBioMaxLength,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell your group a little about you',
              ),
            ),
            const SizedBox(height: 4),
            Text('User ID', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            SelectableText(_userId ?? ''),
            const SizedBox(height: 12),
            Text('Public Key', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 96),
              child: SingleChildScrollView(child: SelectableText(_publicKey)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saving ? null : _regenerateKeys,
                  child: const Text('Regenerate Keys'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
