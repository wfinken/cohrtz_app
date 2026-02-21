import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import '../../../../app/di/app_providers.dart';
import 'poll_status_badge.dart';
import 'poll_timer_badge.dart';
import 'poll_progress_bar.dart';
import 'poll_voted_indicator.dart';

class PollCard extends ConsumerWidget {
  final PollItem poll;
  final DashboardRepository repo;

  const PollCard({super.key, required this.poll, required this.repo});

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}D AGO';
    if (diff.inHours > 0) return '${diff.inHours}H AGO';
    if (diff.inMinutes > 0) return '${diff.inMinutes}M AGO';
    return 'JUST NOW';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final effectivePoll = poll;
    final hasVoted = myId != null && effectivePoll.votedUserIds.contains(myId);
    final outcome = effectivePoll.outcomeAt(now);
    final isPassed = outcome == PollOutcomeState.approved;
    final isClosed = outcome != PollOutcomeState.active;
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final canVote = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.interactPolls),
      orElse: () => false,
    );
    final canRemove = permissionsAsync.maybeWhen(
      data: (permissions) {
        final isCreator = myId != null && myId == effectivePoll.creatorId;
        final isAdmin = PermissionUtils.has(
          permissions,
          PermissionFlags.administrator,
        );
        final canManage = PermissionUtils.has(
          permissions,
          PermissionFlags.managePolls,
        );
        return isCreator || isAdmin || canManage;
      },
      orElse: () => false,
    );

    final approvedPct = effectivePoll.requiredVotes > 0
        ? (effectivePoll.approvedCount / effectivePoll.requiredVotes).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final refusedPct = effectivePoll.requiredVotes > 0
        ? (effectivePoll.rejectedCount / effectivePoll.requiredVotes).clamp(
            0.0,
            1.0 - approvedPct,
          )
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 350;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isClosed
                  ? (isPassed
                        ? colorScheme.tertiary.withValues(alpha: 0.3)
                        : colorScheme.error.withValues(alpha: 0.3))
                  : colorScheme.outlineVariant.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isClosed)
                      PollStatusBadge(isPassed: isPassed)
                    else
                      PollTimerBadge(
                        isUrgent: effectivePoll.isUrgent,
                        endTime: effectivePoll.endTime,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      effectivePoll.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        effectivePoll.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isClosed)
                      PollStatusBadge(isPassed: isPassed)
                    else
                      PollTimerBadge(
                        isUrgent: effectivePoll.isUrgent,
                        endTime: effectivePoll.endTime,
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              if (isCompact) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${effectivePoll.approvedCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.tertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.cancel, size: 14, color: colorScheme.error),
                        const SizedBox(width: 4),
                        Text(
                          '${effectivePoll.rejectedCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${effectivePoll.requiredVotes}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'APPROVE: ${effectivePoll.approvedCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.tertiary,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'REJECT: ${effectivePoll.rejectedCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'MEMBERS: ${effectivePoll.requiredVotes}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    'MAJORITY: ${effectivePoll.majorityPolicy.shortLabel.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (effectivePoll.majorityPolicy == PollMajorityPolicy.simple)
                    Text(
                      'TIE: ${effectivePoll.tiebreakerPolicy.shortLabel.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              PollProgressBar(
                approvedPct: approvedPct,
                refusedPct: refusedPct,
                approvedCount: effectivePoll.approvedCount,
                refusedCount: effectivePoll.rejectedCount,
                goal: effectivePoll.requiredVotes,
              ),
              const SizedBox(height: 16),
              if (isClosed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ENDED ${_getTimeAgo(effectivePoll.endTime)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (canRemove)
                      TextButton(
                        onPressed: () => repo.deletePoll(poll.id),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'REMOVE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                )
              else if (effectivePoll.pendingVoters.isNotEmpty && hasVoted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${effectivePoll.pendingVoters.length} STILL TO VOTE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    const PollVotedIndicator(),
                  ],
                )
              else if (!hasVoted)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 8 : 0,
                          ),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: canVote
                            ? () {
                                if (myId == null) return;
                                final newVoted = [
                                  ...effectivePoll.votedUserIds,
                                  myId,
                                ];
                                final creatorVote =
                                    myId == effectivePoll.creatorId
                                    ? PollVoteChoice.reject
                                    : effectivePoll.creatorVote;
                                final updated = effectivePoll.copyWith(
                                  rejectedCount:
                                      effectivePoll.rejectedCount + 1,
                                  votedUserIds: newVoted,
                                  creatorVote: creatorVote,
                                );
                                repo.savePoll(updated);
                              }
                            : null,
                        child: Text(
                          'NO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 12 : 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 8 : 0,
                          ),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: canVote
                            ? () {
                                if (myId == null) return;
                                final newVoted = [
                                  ...effectivePoll.votedUserIds,
                                  myId,
                                ];
                                final creatorVote =
                                    myId == effectivePoll.creatorId
                                    ? PollVoteChoice.approve
                                    : effectivePoll.creatorVote;
                                final updated = effectivePoll.copyWith(
                                  approvedCount:
                                      effectivePoll.approvedCount + 1,
                                  votedUserIds: newVoted,
                                  creatorVote: creatorVote,
                                );
                                repo.savePoll(updated);
                              }
                            : null,
                        child: Text(
                          'YES',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                            fontSize: isCompact ? 12 : 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Row(children: [Spacer(), PollVotedIndicator()]),
            ],
          ),
        );
      },
    );
  }
}
