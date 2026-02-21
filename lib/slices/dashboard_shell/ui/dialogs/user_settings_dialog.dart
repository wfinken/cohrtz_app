import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import '../../../../app/di/app_providers.dart';

class UserSettingsDialog extends ConsumerStatefulWidget {
  const UserSettingsDialog({super.key});

  @override
  ConsumerState<UserSettingsDialog> createState() => _UserSettingsDialogState();
}

class _UserSettingsDialogState extends ConsumerState<UserSettingsDialog> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _initialized = false;
  String? _myId;
  String? _currentPublicKey;

  @override
  Widget build(BuildContext context) {
    // Determine my ID from global identity
    final identityService = ref.watch(identityServiceProvider);
    final myProfile = identityService.profile;

    if (!_initialized && myProfile != null) {
      _myId = myProfile.id;
      _nameController.text = myProfile.displayName;
      _currentPublicKey = myProfile.publicKey;
      _initialized = true;
    }

    if (myProfile == null) {
      return const Center(child: CircularProgressIndicator());
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
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'User Settings',
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
              'Display Name',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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

  Future<void> _saveProfile() async {
    if (_myId == null) return;

    setState(() => _isLoading = true);
    try {
      final identityService = ref.read(identityServiceProvider);
      final repo = ref.read(dashboardRepositoryProvider);

      final newName = _nameController.text.trim().isEmpty
          ? 'Anonymous'
          : _nameController.text.trim();
      final newProfile = UserProfile(
        id: _myId!,
        displayName: newName,
        publicKey: _currentPublicKey ?? '',
      );

      // Update global identity
      await identityService.saveProfile(newProfile);

      // Update current room profile
      await repo.saveUserProfile(newProfile);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('[UserSettingsDialog] Error saving user profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
