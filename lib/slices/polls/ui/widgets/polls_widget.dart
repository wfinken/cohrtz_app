import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import '../dialogs/create_poll_dialog.dart';
import 'package:cohortz/slices/dashboard_shell/ui/dashboard_edit_notifier.dart';
import 'poll_card.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/ghost_add_button.dart';

class PollsWidget extends ConsumerWidget {
  const PollsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollsAsync = ref.watch(visiblePollsStreamProvider);
    final repo = ref.watch(dashboardRepositoryProvider);
    final isEditMode = ref.watch(dashboardEditProvider).isEditing;

    return pollsAsync.when(
      data: (polls) {
        final permissionsAsync = ref.watch(currentUserPermissionsProvider);
        final canCreatePolls = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.createPolls),
          orElse: () => false,
        );
        final canManagePolls = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.managePolls),
          orElse: () => false,
        );
        final isAdmin = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.administrator),
          orElse: () => false,
        );

        final canAdd = canCreatePolls || canManagePolls || isAdmin;

        if (polls.isEmpty) {
          if (!canAdd) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GhostAddButton(
                label: 'Create Poll',
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                borderRadius: 8,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const CreatePollDialog(),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: polls.length + (canAdd ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index < polls.length) {
                  final poll = polls[index];
                  Widget item = PollCard(poll: poll, repo: repo);
                  if (isEditMode) {
                    item = ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.grey,
                        BlendMode.saturation,
                      ),
                      child: item,
                    );
                  }
                  return item;
                }
                return GhostAddButton(
                  label: 'Create Poll',
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  borderRadius: 8,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const CreatePollDialog(),
                  ),
                );
              },
            ),
            if (isEditMode)
              Positioned.fill(
                child: Container(
                  color: Colors.transparent, // Blocks interaction
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

final visiblePollsStreamProvider = StreamProvider<List<PollItem>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final myGroupIds = ref.watch(myLogicalGroupIdsProvider);
  final isOwner = ref.watch(currentUserIsOwnerProvider);
  final permissions = ref.watch(currentUserPermissionsProvider).value;
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));
  return repo.watchPolls().map((polls) {
    return polls
        .where(
          (poll) => canViewByLogicalGroups(
            itemGroupIds: poll.visibilityGroupIds,
            viewerGroupIds: myGroupIds,
            bypass: bypass,
          ),
        )
        .toList();
  });
});
