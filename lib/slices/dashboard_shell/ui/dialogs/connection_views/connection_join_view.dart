import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../shared/theme/tokens/app_shape_tokens.dart';

class ConnectionJoinView extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String groupName, String inviteCode) onJoin;
  final String initialGroupName;

  const ConnectionJoinView({
    super.key,
    required this.onBack,
    required this.onJoin,
    this.initialGroupName = '',
  });

  @override
  State<ConnectionJoinView> createState() => _ConnectionJoinViewState();
}

class _ConnectionJoinViewState extends State<ConnectionJoinView> {
  late TextEditingController groupController;
  final List<TextEditingController> _digitControllers = List.generate(
    8,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    groupController = TextEditingController(text: widget.initialGroupName);
  }

  @override
  void dispose() {
    groupController.dispose();
    for (var controller in _digitControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleJoin() {
    final inviteCode = _digitControllers.map((c) => c.text).join();
    widget.onJoin(groupController.text.trim(), inviteCode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent()},
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _handleJoin(),
          ),
        },
        child: Dialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: context.appBorderRadius(16),
            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: Icon(
                        Icons.arrow_back,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Text(
                      'Join Existing Group',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Group Name Input
                Text(
                  'GROUP NAME',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: groupController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Enter the group name...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: context.appBorderRadius(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: context.appBorderRadius(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Invite Code Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'INVITE CODE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'Ask admin for code',
                      style: TextStyle(
                        color: Color(0xFF10B981), // emerald500
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: context.appBorderRadius(12),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) => _buildDigitField(index, colorScheme),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: context.appBorderRadius(12),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) => _buildDigitField(index + 4, colorScheme),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: context.appBorderRadius(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'By joining a group, you will gain access to shared calendars, vaults, and chores.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Join Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleJoin,
                    child: const Text('Join Group'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitField(int index, ColorScheme colorScheme) {
    return Container(
      width: 32,
      alignment: Alignment.center,
      child: TextField(
        controller: _digitControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.text,
        enableSuggestions: false,
        autocorrect: false,
        textCapitalization: TextCapitalization.characters,
        textInputAction: index < 7
            ? TextInputAction.next
            : TextInputAction.done,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          fontFamily: 'Monospace',
        ),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onChanged: (value) {
          if (value.length > 1) {
            // Handle paste
            final digits = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            for (int i = 0; i < digits.length && (index + i) < 8; i++) {
              _digitControllers[index + i].text = digits[i];
            }
            final lastPastedIndex = index + digits.length - 1;
            final targetIndex = lastPastedIndex < 7 ? lastPastedIndex + 1 : 7;
            _focusNodes[targetIndex].requestFocus();
          } else if (value.isNotEmpty) {
            if (index < 7) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
            }
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
        onSubmitted: (_) {
          if (index < 7) {
            _focusNodes[index + 1].requestFocus();
          } else {
            _handleJoin();
          }
        },
      ),
    );
  }
}
