import 'package:cohortz/core/database/database.dart';
import 'package:cohortz/features/notes/data/note_repository.dart';
import 'package:cohortz/features/notes/domain/note_model.dart';
import 'package:cohortz/features/sync/infrastructure/crdt_service.dart';
import 'package:cohortz/features/sync/infrastructure/hybrid_time_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class TestCrdtService extends Fake implements CrdtService {
  TestCrdtService(this.db);

  final AppDatabase db;

  @override
  AppDatabase? getDatabase(String roomName) => db;

  @override
  Future<void> delete(String roomName, String key, String tableName) async {}
}

void main() {
  test('watchNotes returns only document rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final crdt = TestCrdtService(db);
    final time = HybridTimeService(getLocalParticipantId: () => 'test-node');
    final repo = NoteRepository(crdt, 'room-1', time);

    await repo.saveNote(
      Note(
        id: 'note-1',
        title: 'Project Notes',
        content: 'Content',
        updatedBy: 'user-1',
        updatedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        logicalTime: 1,
      ),
    );

    final notes = await repo.watchNotes().first;

    expect(notes.length, 1);
    expect(notes.first.id, 'note-1');
    expect(notes.first.title, 'Project Notes');
  });

  test('watchDocument maps note by id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final crdt = TestCrdtService(db);
    final time = HybridTimeService(getLocalParticipantId: () => 'test-node');
    final repo = NoteRepository(crdt, 'room-1', time);

    await repo.saveNote(
      Note(
        id: 'note-1',
        title: 'Project Notes',
        content: 'Body',
        updatedBy: 'user-1',
        updatedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        logicalTime: 1,
      ),
    );

    final note = await repo.watchDocument('note-1').first;

    expect(note, isNotNull);
    expect(note!.id, 'note-1');
    expect(note.title, 'Project Notes');
  });

  test('watchActiveEditors returns active presence records', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final crdt = TestCrdtService(db);
    final time = HybridTimeService(getLocalParticipantId: () => 'test-node');
    final repo = NoteRepository(crdt, 'room-1', time);

    await repo.touchPresence(
      documentId: 'note-1',
      userId: 'user-1',
      displayName: 'Alex',
      colorHex: '#3B82F6',
      isEditing: true,
      at: DateTime.now(),
    );

    final editors = await repo.watchActiveEditors('note-1').first;

    expect(editors.length, 1);
    expect(editors.first.userId, 'user-1');
    expect(editors.first.displayName, 'Alex');
  });

  test('watchNotes returns empty list without room', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final crdt = TestCrdtService(db);
    final time = HybridTimeService(getLocalParticipantId: () => 'test-node');
    final repo = NoteRepository(crdt, null, time);

    final notes = await repo.watchNotes().first;

    expect(notes, isEmpty);
  });
}
