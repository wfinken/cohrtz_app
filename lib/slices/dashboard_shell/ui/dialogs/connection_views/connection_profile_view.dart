import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../shared/theme/tokens/app_shape_tokens.dart';

class ConnectionProfileView extends StatefulWidget {
  const ConnectionProfileView({
    super.key,
    required this.groupName,
    required this.initialDisplayName,
    required this.submitLabel,
    required this.onBack,
    required this.onContinue,
  });

  final String groupName;
  final String initialDisplayName;
  final String submitLabel;
  final VoidCallback onBack;
  final ValueChanged<String> onContinue;

  @override
  State<ConnectionProfileView> createState() => _ConnectionProfileViewState();
}

class _ConnectionProfileViewState extends State<ConnectionProfileView> {
  late final TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialDisplayName,
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _displayNameController.text.trim();
    if (name.isEmpty) return;
    widget.onContinue(name);
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
            onInvoke: (_) => _continue(),
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
                    ),
                    Text(
                      'Choose Your Name',
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
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'This name will be used only in "${widget.groupName}".',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'DISPLAY NAME',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _displayNameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. Alice',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: context.appBorderRadius(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: Text(widget.submitLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
