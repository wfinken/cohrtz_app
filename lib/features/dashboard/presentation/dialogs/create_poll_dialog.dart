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

class CreatePollDialog extends ConsumerStatefulWidget {
  const CreatePollDialog({super.key});

  @override
  ConsumerState<CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends ConsumerState<CreatePollDialog> {
  final _questionController = TextEditingController();
  final _durationController = TextEditingController(text: '2');
  bool _isUrgent = false;
  PollMajorityPolicy _majorityPolicy = PollMajorityPolicy.simple;
  PollTiebreakerPolicy _tiebreakerPolicy = PollTiebreakerPolicy.statusQuo;

  @override
  void dispose() {
    _questionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _submit(bool hasPermission) {
    if (!hasPermission) return;
    final profilesAsync = ref.read(userProfilesProvider);
    final memberCount = profilesAsync.maybeWhen(
      data: (profiles) => profiles.length,
      orElse: () => 1,
    );
    final question = _questionController.text;
    final requiredVotes = memberCount <= 0 ? 1 : memberCount;
    final durationHours = int.tryParse(_durationController.text) ?? 2;
    final endTime = DateTime.now().add(Duration(hours: durationHours));
    final creatorId = ref.read(syncServiceProvider).identity ?? '';

    final newPoll = PollItem(
      id: const Uuid().v4(),
      question: question,
      approvedCount: 0,
      requiredVotes: requiredVotes,
      endTime: endTime,
      durationHours: durationHours,
      pendingVoters: [], // Initial state has no voters or logic to add them yet
      votedUserIds: [],
      rejectedCount: 0,
      isUrgent: _isUrgent,
      tiebreakerPolicy: _tiebreakerPolicy,
      majorityPolicy: _majorityPolicy,
      creatorId: creatorId,
    );

    ref.read(dashboardRepositoryProvider).savePoll(newPoll);
    Navigator.of(context).pop();
  }

  TextStyle _sectionLabelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        );
  }

  Widget _sectionLabel(BuildContext context, String text, {IconData? icon}) {
    final style = _sectionLabelStyle(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: style.color?.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
        ],
        Text(text.toUpperCase(), style: style),
      ],
    );
  }

  String _majorityHint(PollMajorityPolicy policy) {
    switch (policy) {
      case PollMajorityPolicy.simple:
        return '> 50% required to pass.';
      case PollMajorityPolicy.superMajority:
        return '≥ 66% required to pass.';
      case PollMajorityPolicy.unanimous:
        return '100% required to pass.';
    }
  }

  Widget _buildTiebreakerGrid({
    required BuildContext context,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isEnabled,
  }) {
    final policies = PollTiebreakerPolicy.values;
    const chipWidth = 112.0;
    const chipHeight = 34.0;
    const spacing = 8.0;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: policies.map((policy) {
        final isSelected = _tiebreakerPolicy == policy;
        return SizedBox(
          width: chipWidth,
          height: chipHeight,
          child: Material(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: isEnabled
                  ? () {
                      setState(() {
                        _tiebreakerPolicy = policy;
                      });
                    }
                  : null,
              child: Center(
                child: Text(
                  policy.shortLabel,
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final permissions = permissionsAsync.value ?? PermissionFlags.none;

    final canCreatePolls = PermissionUtils.has(
      permissions,
      PermissionFlags.createPolls,
    );
    final canManagePolls = PermissionUtils.has(
      permissions,
      PermissionFlags.managePolls,
    );
    final isAdmin = PermissionUtils.has(
      permissions,
      PermissionFlags.administrator,
    );

    final hasPermission = canCreatePolls || canManagePolls || isAdmin;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
    final segmentedStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.surfaceContainerLow;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.onSurface;
        }
        return colorScheme.onSurfaceVariant;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.outlineVariant;
        return BorderSide(color: color.withValues(alpha: 0.7));
      }),
      textStyle: WidgetStateProperty.all(
        theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent()},
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _submit(hasPermission),
          ),
        },
        child: Focus(
          autofocus: true,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.dialogRadius),
              ),
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CREATE POLL',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            color: colorScheme.onSurfaceVariant,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Form(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!hasPermission)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'You do not have permission to create polls.',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _sectionLabel(context, 'Question'),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _questionController,
                                  enabled: hasPermission,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                  decoration: inputDecoration.copyWith(
                                    hintText: 'What are we voting on?',
                                  ),
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _sectionLabel(
                                    context,
                                    'Duration (Hrs)',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _durationController,
                                  enabled: hasPermission,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                  decoration: inputDecoration.copyWith(
                                    hintText: '2',
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) =>
                                      _submit(hasPermission),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.flash_on,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Mark as Urgent',
                                              style: theme.textTheme.labelLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Notifies everyone immediately',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.8),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _isUrgent,
                                        onChanged: hasPermission
                                            ? (val) => setState(
                                                () => _isUrgent = val,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _sectionLabel(
                                    context,
                                    'Majority Requirement',
                                    icon: Icons.balance,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<PollMajorityPolicy>(
                                  segments: PollMajorityPolicy.values
                                      .map(
                                        (policy) =>
                                            ButtonSegment<PollMajorityPolicy>(
                                              value: policy,
                                              label: Text(policy.shortLabel),
                                            ),
                                      )
                                      .toList(),
                                  selected: {_majorityPolicy},
                                  showSelectedIcon: false,
                                  style: segmentedStyle,
                                  onSelectionChanged: hasPermission
                                      ? (selection) {
                                          setState(() {
                                            _majorityPolicy = selection.first;
                                          });
                                        }
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _majorityHint(_majorityPolicy),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                if (_majorityPolicy ==
                                    PollMajorityPolicy.simple) ...[
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _sectionLabel(
                                      context,
                                      'Tiebreaker Policy',
                                      icon: Icons.gavel,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: _buildTiebreakerGrid(
                                      context: context,
                                      colorScheme: colorScheme,
                                      textTheme: theme.textTheme,
                                      isEnabled: hasPermission,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _tiebreakerPolicy.description,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.8),
                                          ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.2,
                              )
                            : colorScheme.surfaceContainerLow,
                        border: Border(
                          top: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(AppTheme.dialogRadius),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: hasPermission
                                  ? () => _submit(true)
                                  : null,
                              child: const Text('Create Poll'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
