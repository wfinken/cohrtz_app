import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/notes/models/note_model.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'sync_service_provider.dart';
import 'note_repository_provider.dart';

final notesListProvider = StreamProvider<List<Note>>((ref) {
  ref.watch(syncServiceProvider.select((s) => s.currentRoomName));
  final repo = ref.watch(noteRepositoryProvider);
  final myGroupIds = ref.watch(myLogicalGroupIdsProvider);
  final isOwner = ref.watch(currentUserIsOwnerProvider);
  final permissions = ref.watch(currentUserPermissionsProvider).value;
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));
  return repo.watchNotes().map((notes) {
    return notes
        .where(
          (note) => canViewByLogicalGroups(
            itemGroupIds: note.visibilityGroupIds,
            viewerGroupIds: myGroupIds,
            bypass: bypass,
          ),
        )
        .toList();
  });
});
