import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';

class LogicalGroupsWidget extends ConsumerWidget {
  const LogicalGroupsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(logicalGroupsProvider);
    final canManage = ref.watch(canManageLogicalGroupsProvider);
    final profiles = ref.watch(userProfilesProvider).value ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Logical Groups',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (canManage)
                  IconButton(
                    tooltip: 'Create group',
                    onPressed: () => _createGroup(context, ref, profiles),
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (groups.isEmpty)
              Text(
                'No logical groups found',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      dense: true,
                      title: Row(
                        children: [
                          Expanded(child: Text(group.name)),
                          if (group.id == AclGroupIds.everyone)
                            const Text(
                              'SYSTEM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${group.memberIds.length} members',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                      trailing: (!group.isSystem && canManage)
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit group',
                                  onPressed: () =>
                                      _editGroup(context, ref, profiles, group),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete group',
                                  onPressed: () =>
                                      _deleteGroup(context, ref, group),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
              ),
            if (!canManage) ...[
              const SizedBox(height: 8),
              Text(
                'Requires Manage Roles + Manage Members.',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(
    BuildContext context,
    WidgetRef ref,
    List<UserProfile> profiles,
  ) async {
    final draft = await _showGroupEditorDialog(context, profiles);
    if (draft == null) return;

    final id = 'logical_group:${const Uuid().v4()}';
    final group = LogicalGroup(
      id: id,
      name: draft.name,
      memberIds: draft.memberIds,
    );
    await ref.read(logicalGroupRepositoryProvider).saveLogicalGroup(group);
  }

  Future<void> _editGroup(
    BuildContext context,
    WidgetRef ref,
    List<UserProfile> profiles,
    LogicalGroup group,
  ) async {
    final draft = await _showGroupEditorDialog(
      context,
      profiles,
      initial: group,
    );
    if (draft == null) return;
    await ref
        .read(logicalGroupRepositoryProvider)
        .saveLogicalGroup(
          group.copyWith(name: draft.name, memberIds: draft.memberIds),
        );
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    LogicalGroup group,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Logical Group?'),
        content: Text('Delete "${group.name}"?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref.read(logicalGroupRepositoryProvider).deleteLogicalGroup(group.id);
  }
}

class _GroupEditorDraft {
  final String name;
  final List<String> memberIds;

  const _GroupEditorDraft({required this.name, required this.memberIds});
}

Future<_GroupEditorDraft?> _showGroupEditorDialog(
  BuildContext context,
  List<UserProfile> profiles, {
  LogicalGroup? initial,
}) async {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final selected = <String>{...?initial?.memberIds};

  final orderedProfiles = List<UserProfile>.from(profiles)
    ..sort((a, b) => a.displayName.compareTo(b.displayName));

  return showDialog<_GroupEditorDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(initial == null ? 'Create Logical Group' : 'Edit Group'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: orderedProfiles.map((profile) {
                    final checked = selected.contains(profile.id);
                    final label = profile.displayName.trim().isEmpty
                        ? profile.id
                        : profile.displayName;
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(profile.id);
                          } else {
                            selected.remove(profile.id);
                          }
                        });
                      },
                      title: Text(label),
                      subtitle: Text(profile.id),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty || name.toLowerCase() == AclGroupIds.everyone) {
                return;
              }
              Navigator.pop(
                context,
                _GroupEditorDraft(
                  name: name,
                  memberIds: selected.toList()..sort(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
