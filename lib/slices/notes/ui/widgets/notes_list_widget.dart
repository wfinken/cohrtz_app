import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../slices/permissions_core/permission_flags.dart';
import '../../../../slices/permissions_core/permission_providers.dart';
import '../../../../slices/permissions_core/permission_utils.dart';
import '../../../../app/di/app_providers.dart';
import '../../../../shared/theme/tokens/dialog_button_styles.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/ghost_add_button.dart';

class NotesListWidget extends ConsumerWidget {
  final ValueChanged<String> onOpenNote;

  const NotesListWidget({super.key, required this.onOpenNote});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesListProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);

    return permissionsAsync.when(
      data: (permissions) {
        final canViewNotes = PermissionUtils.has(
          permissions,
          PermissionFlags.viewNotes,
        );
        if (!canViewNotes) {
          return Center(
            child: Text(
              'Notes locked',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          );
        }
        final canCreateNotes = PermissionUtils.has(
          permissions,
          PermissionFlags.createNotes,
        );
        final canManageNotes = PermissionUtils.has(
          permissions,
          PermissionFlags.manageNotes,
        );
        final isAdmin = PermissionUtils.has(
          permissions,
          PermissionFlags.administrator,
        );

        final canAdd = canCreateNotes || canManageNotes || isAdmin;

        return notesAsync.when(
          data: (notes) {
            if (notes.isEmpty) {
              if (!canAdd) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GhostAddButton(
                    label: 'Open Notes Editor',
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    borderRadius: 8,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    onTap: () => onOpenNote('note:shared'),
                  ),
                ],
              );
            }

            return ListView.separated(
              itemCount: notes.length + (canAdd ? 1 : 0),
              separatorBuilder: (_, __) =>
                  Divider(color: Theme.of(context).dividerColor, height: 1),
              itemBuilder: (context, index) {
                if (canAdd && index == notes.length) {
                  return GhostAddButton(
                    label: 'New Note',
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    borderRadius: 8,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    onTap: () => onOpenNote('note:create'),
                  );
                }

                final note = notes[index];
                final preview = note.content.trim().isEmpty
                    ? 'No content'
                    : note.content.trim().replaceAll('\n', ' ');
                return InkWell(
                  onTap: () => onOpenNote(note.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (canManageNotes)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            tooltip: 'Delete note',
                            onPressed: () =>
                                _confirmDelete(context, ref, note.id),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Error loading notes',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error loading permissions',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String noteId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: dialogDestructiveButtonStyle(dialogContext),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(noteRepositoryProvider).deleteNote(noteId);
  }
}
