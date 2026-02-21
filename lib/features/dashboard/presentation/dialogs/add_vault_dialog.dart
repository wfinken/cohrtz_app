import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/permissions/permission_flags.dart';
import '../../../../core/permissions/permission_providers.dart';
import '../../../../core/permissions/permission_utils.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_models.dart';

class AddVaultDialog extends ConsumerStatefulWidget {
  const AddVaultDialog({super.key});

  @override
  ConsumerState<AddVaultDialog> createState() => _AddVaultDialogState();
}

class _AddVaultDialogState extends ConsumerState<AddVaultDialog> {
  final _labelController = TextEditingController();
  final _valueController = TextEditingController();
  String _selectedType = 'password';
  bool _obscureText = true;
  bool _isSaving = false;

  final List<String> _types = ['password', 'wifi', 'card', 'code', 'note'];

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final permissions = permissionsAsync.value ?? PermissionFlags.none;

    final canCreateVault = PermissionUtils.has(
      permissions,
      PermissionFlags.createVault,
    );
    final canManageVault = PermissionUtils.has(
      permissions,
      PermissionFlags.manageVault,
    );
    final isAdmin = PermissionUtils.has(
      permissions,
      PermissionFlags.administrator,
    );

    final hasPermission = canCreateVault || canManageVault || isAdmin;
    final theme = Theme.of(context);

    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent()},
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _save(hasPermission),
          ),
        },
        child: Focus(
          autofocus: true,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Dialog(
              child: SizedBox(
                width: 496,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: _buildHeader(hasPermission, theme),
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 24),
                              _buildCategorySelector(hasPermission, theme),
                              const SizedBox(height: 24),
                              _buildInputs(context, hasPermission, theme),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(hasPermission, theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasPermission, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: colorScheme.tertiary),
            const SizedBox(width: 8),
            Text(
              'SECURE STORAGE',
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        ElevatedButton(
          onPressed: hasPermission ? () => _save(hasPermission) : null,
          child: const Text('Lock It'),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(bool hasPermission, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY',
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _types.map((type) {
            final isSelected = _selectedType == type;
            return GestureDetector(
              onTap: hasPermission
                  ? () => setState(() => _selectedType = type)
                  : null,
              child: Container(
                width: 80,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.tertiary
                        : theme.dividerColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.tertiary
                            : (isDark
                                  ? colorScheme.surfaceContainerHigh
                                  : colorScheme.surfaceContainerLow),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForType(type),
                        size: 18,
                        color: isSelected
                            ? Colors.white
                            : theme.iconTheme.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatType(type),
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onSurface
                            : theme.hintColor,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInputs(
    BuildContext context,
    bool hasPermission,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final inputFillColor = colorScheme.surfaceContainerLowest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITEM LABEL',
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _labelController,
          enabled: hasPermission,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          cursorColor: colorScheme.tertiary,
          decoration: InputDecoration(
            hintText: 'e.g. Netflix Password',
            hintStyle: TextStyle(color: theme.hintColor),
            prefixIcon: Icon(
              _getIconForType(_selectedType),
              color: colorScheme.tertiary,
              size: 20,
            ),
            filled: true,
            fillColor: inputFillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.tertiary),
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SECRET VALUE',
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            _selectedType == 'password'
                ? InkWell(
                    onTap: hasPermission ? _generateStrongPassword : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHigh
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 12,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Generate Strong',
                            style: TextStyle(
                              color: colorScheme.tertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _valueController,
          enabled: hasPermission,
          obscureText:
              (_selectedType == 'password' || _selectedType == 'card') &&
              _obscureText,
          maxLines: _selectedType == 'note' ? 3 : 1,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontFamily: 'monospace',
          ),
          cursorColor: colorScheme.tertiary,
          decoration: InputDecoration(
            hintText: 'Enter secure data...',
            hintStyle: TextStyle(color: theme.hintColor),
            suffixIcon: (_selectedType == 'password' || _selectedType == 'card')
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: theme.iconTheme.color,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  )
                : null,
            filled: true,
            fillColor: inputFillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.tertiary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool hasPermission, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.dialogRadius),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 14, color: colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This value will be end-to-end encrypted before it leaves your device. Only members of this group can decrypt it.',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (hasPermission && !_isSaving)
                    ? () => _save(true)
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(_isSaving ? 'Saving...' : 'Lock It Away'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateStrongPassword() {
    // Simple random password generator
    const length = 16;
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890!@#\$%^&*()';
    final random = DateTime.now().millisecondsSinceEpoch;

    final password = List.generate(
      length,
      (index) => chars[(index * random + index) % chars.length],
    ).join();

    setState(() {
      _valueController.text = password;
    });
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'wifi':
        return Icons.wifi;
      case 'card':
        return Icons.credit_card;
      case 'note':
        return Icons.sticky_note_2_outlined; // Use outlined for better match
      case 'code':
        return Icons.lock_clock_outlined;
      case 'password':
      default:
        return Icons.vpn_key_outlined;
    }
  }

  String _formatType(String type) {
    if (type == 'wifi') return 'Wi-Fi';
    if (type == 'secure note' || type == 'note') return 'Secure Note';
    return type[0].toUpperCase() + type.substring(1);
  }

  Future<void> _save(bool hasPermission) async {
    if (!hasPermission) return;
    if (_isSaving) return;
    final encryptionService = ref.read(encryptionServiceProvider);

    // Show saving feedback if needed, but dialog usually closes fast.

    if (!mounted) return;
    setState(() => _isSaving = true);

    final syncService = ref.read(syncServiceProvider);
    final roomName = syncService.currentRoomName;

    if (roomName == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No active room found!')));
      }
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      final key = await syncService.getVaultKey(
        roomName,
        allowGenerateIfMissing: true,
      );

      if (!mounted) return;

      final encryptedBytes = await encryptionService.encrypt(
        utf8.encode(_valueController.text),
        key,
      );
      final encrypted = base64Encode(encryptedBytes);

      final item = VaultItem(
        id: 'secret:${const Uuid().v4()}',
        label: _labelController.text,
        type: _selectedType,
        encryptedValue: encrypted,
        creatorId: syncService.identity ?? '',
      );

      if (!mounted) return;
      ref.read(dashboardRepositoryProvider).saveVaultItem(item);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[AddVaultDialog] Failed to save vault item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vault is locked (missing key). Try again in a bit.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
