import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/notes/models/note_model.dart';
import 'package:cohortz/slices/notes/state/note_repository.dart';
import 'package:cohortz/slices/notes/ui/widgets/notes_widget.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/sync/orchestration/processes/network_recovery_process.dart';
import 'package:cohortz/slices/sync/orchestration/sync_service.dart';
import 'package:cohortz/slices/sync/runtime/hybrid_time_service.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';

import '../../helpers/mocks.dart';

class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository({this.activeEditors = const []})
    : super(
        FakeCrdtService(),
        'room-1',
        HybridTimeService(getLocalParticipantId: () => 'test-user-id'),
      );

  final List<NoteEditorPresence> activeEditors;
  String? deletedNoteId;
  Note? savedNote;

  @override
  Future<void> saveNote(Note note) async {
    savedNote = note;
  }

  @override
  Future<void> deleteNote(String documentId) async {
    deletedNoteId = documentId;
  }

  @override
  Future<void> touchPresence({
    required String documentId,
    required String userId,
    required String displayName,
    required String colorHex,
    bool isEditing = true,
    DateTime? at,
  }) async {}

  @override
  Future<void> clearPresence({
    required String documentId,
    required String userId,
  }) async {}

  @override
  Stream<List<NoteEditorPresence>> watchActiveEditors(
    String documentId, {
    Duration activeThreshold = const Duration(seconds: 20),
  }) {
    return Stream.value(activeEditors);
  }
}

class FakeSyncService extends SyncService {
  FakeSyncService()
    : super(
        connectionManager: FakeConnectionManager(),
        groupManager: FakeGroupManager(),
        keyManager: FakeKeyManager(),
        inviteHandler: FakeInviteHandler(),
        networkRecoveryProcess: NetworkRecoveryProcess(
          connectionManager: FakeConnectionManager(),
        ),
      );

  @override
  String? get identity => 'test-user-id';

  @override
  String? get activeRoomName => 'room-1';

  @override
  String? get currentRoomName => 'room-1';

  @override
  String? get localParticipantId => 'test-user-id';
}

class FakeSyncServiceNotifier extends SyncServiceNotifier {
  final FakeSyncService _fakeService;

  FakeSyncServiceNotifier(this._fakeService);

  @override
  SyncService build() => _fakeService;
}

Note _note() {
  return Note(
    id: 'note:1',
    title: 'Project Notes',
    content: 'A note body',
    updatedBy: 'test-user-id',
    updatedAt: DateTime(2026, 2, 20),
    logicalTime: 1,
    visibilityGroupIds: const [AclGroupIds.everyone],
  );
}

Widget _buildWidget({
  required FakeNoteRepository repository,
  required List<Note> notes,
  required int permissions,
  List<UserProfile> profiles = const [],
  Set<String> connectedParticipants = const {'test-user-id'},
}) {
  return ProviderScope(
    overrides: [
      noteRepositoryProvider.overrideWithValue(repository),
      notesListProvider.overrideWith((ref) => Stream.value(notes)),
      currentUserPermissionsProvider.overrideWith((ref) async => permissions),
      logicalGroupsProvider.overrideWith(
        (ref) => const [
          LogicalGroup(
            id: AclGroupIds.everyone,
            name: 'Everyone',
            isSystem: true,
          ),
        ],
      ),
      connectedParticipantIdentitiesProvider.overrideWith(
        (ref) => connectedParticipants,
      ),
      userProfilesProvider.overrideWith((ref) => Stream.value(profiles)),
      syncServiceProvider.overrideWith(
        () => FakeSyncServiceNotifier(FakeSyncService()),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: NotesWidget(initialDocumentId: notes.first.id)),
    ),
  );
}

void main() {
  testWidgets('toolbar is hidden in view mode and visible in edit mode', (
    tester,
  ) async {
    final repository = FakeNoteRepository();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        notes: [_note()],
        permissions: PermissionFlags.viewNotes | PermissionFlags.editNotes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notes_toolbar')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('notes_mode_edit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notes_toolbar')), findsOneWidget);
  });

  testWidgets(
    'options tab is visible for read-only users with gated controls',
    (tester) async {
      final repository = FakeNoteRepository();

      await tester.pumpWidget(
        _buildWidget(
          repository: repository,
          notes: [_note()],
          permissions: PermissionFlags.viewNotes,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notes_mode_edit')), findsNothing);
      expect(find.byKey(const ValueKey('notes_mode_options')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('notes_mode_options')));
      await tester.pumpAndSettle();

      final visibilityButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('notes_options_visibility_button')),
      );
      final deleteButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('notes_options_delete_button')),
      );

      expect(visibilityButton.onPressed, isNull);
      expect(deleteButton.onPressed, isNull);
    },
  );

  testWidgets('options delete action removes the note for managers', (
    tester,
  ) async {
    final repository = FakeNoteRepository();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        notes: [_note()],
        permissions:
            PermissionFlags.viewNotes |
            PermissionFlags.editNotes |
            PermissionFlags.manageNotes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes_mode_options')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes_options_delete_button')));
    await tester.pumpAndSettle();

    expect(find.text('Delete note?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedNoteId, 'note:1');
  });

  testWidgets('editing now uses profile avatars for active editors', (
    tester,
  ) async {
    final repository = FakeNoteRepository(
      activeEditors: [
        NoteEditorPresence(
          documentId: 'note:1',
          userId: 'user-2',
          displayName: 'Alex',
          colorHex: '#3B82F6',
          isEditing: true,
          lastSeenAt: DateTime(2026, 2, 20, 12),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        notes: [_note()],
        permissions: PermissionFlags.viewNotes | PermissionFlags.editNotes,
        connectedParticipants: const {'test-user-id', 'user-2'},
        profiles: [
          UserProfile(
            id: 'user-2',
            displayName: 'Alex Rivera',
            publicKey: 'key',
            avatarBase64: '',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editing now'), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsOneWidget);
  });
}
