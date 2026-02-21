import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/database/database.dart';
import '../../sync/runtime/crdt_service.dart';
import '../../sync/runtime/hybrid_time_service.dart';
import '../models/note_model.dart';
import '../../../shared/utils/logging_service.dart';

class NoteRepository {
  static const String _documentsPrefix = 'doc:';
  static const String _presencePrefix = 'presence:';

  final CrdtService _crdtService;
  final String? _roomName;
  final HybridTimeService _hybridTimeService;

  NoteRepository(this._crdtService, this._roomName, this._hybridTimeService);

  AppDatabase? get _db =>
      _roomName != null ? _crdtService.getDatabase(_roomName) : null;

  Future<void> saveNote(Note note) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.notes)
        .insertOnConflictUpdate(
          NoteEntity(
            id: _documentKey(note.id),
            value: note.toJson(),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteNote(String documentId) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    await _crdtService.delete(roomName, _documentKey(documentId), 'notes');
  }

  Future<void> touchPresence({
    required String documentId,
    required String userId,
    required String displayName,
    required String colorHex,
    bool isEditing = true,
    DateTime? at,
  }) async {
    final db = _db;
    if (db == null) return;
    final time = _hybridTimeService;
    final presence = NoteEditorPresence(
      documentId: documentId,
      userId: userId,
      displayName: displayName,
      colorHex: colorHex,
      isEditing: isEditing,
      lastSeenAt: at ?? time.getAdjustedTimeLocal(),
      logicalTime: time.nextLogicalTime(),
    );

    await db
        .into(db.notes)
        .insertOnConflictUpdate(
          NoteEntity(
            id: _presenceKey(documentId, userId),
            value: presence.toJson(),
            isDeleted: 0,
          ),
        );
  }

  Future<void> clearPresence({
    required String documentId,
    required String userId,
  }) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;
    await _crdtService.delete(
      roomName,
      _presenceKey(documentId, userId),
      'notes',
    );
  }

  Stream<List<Note>> watchNotes() {
    final db = _db;
    if (db == null) return Stream.value([]);
    return (db.select(db.notes)
          ..where((t) => t.isDeleted.equals(0))
          ..where((t) => t.id.like('$_presencePrefix%').not()))
        .watch()
        .map((rows) {
          final documents = rows
              .map((row) {
                try {
                  final jsonStr = row.value;
                  return _normalizeNote(NoteMapper.fromJson(jsonStr));
                } catch (e) {
                  Log.e(
                    '[NoteRepository]',
                    'Error decoding Note: ${row.value}',
                    e,
                  );
                  return null;
                }
              })
              .whereType<Note>()
              .toList();
          documents.sort((a, b) {
            final byPhysical = b.updatedAt.millisecondsSinceEpoch.compareTo(
              a.updatedAt.millisecondsSinceEpoch,
            );
            if (byPhysical != 0) return byPhysical;
            return b.logicalTime.compareTo(a.logicalTime);
          });
          return documents;
        });
  }

  Stream<Note?> watchDocument(String documentId) {
    final db = _db;
    if (db == null) return Stream.value(null);
    return (db.select(db.notes)
          ..where(
            (t) =>
                (t.id.equals(_documentKey(documentId)) |
                    t.id.equals(documentId)) &
                t.isDeleted.equals(0),
          )
          ..limit(1))
        .watchSingleOrNull()
        .map((row) {
          if (row == null) return null;
          try {
            final value = row.value;
            return _normalizeNote(NoteMapper.fromJson(value));
          } catch (_) {
            return null;
          }
        });
  }

  Stream<List<NoteEditorPresence>> watchActiveEditors(
    String documentId, {
    Duration activeThreshold = const Duration(seconds: 20),
  }) {
    final db = _db;
    if (db == null) return Stream.value([]);

    final prefix = '${_presencePrefixForDocument(documentId)}%';
    final source =
        (db.select(db.notes)
              ..where((t) => t.id.like(prefix))
              ..where((t) => t.isDeleted.equals(0)))
            .watch();

    return Stream.multi((controller) {
      List<NoteEditorPresence> latest = [];

      List<NoteEditorPresence> filterActive() {
        final now = _hybridTimeService.getAdjustedTimeLocal();
        final active = latest.where((presence) {
          if (!presence.isEditing) return false;
          return now.difference(presence.lastSeenAt) <= activeThreshold;
        }).toList();
        active.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        return active;
      }

      final subscription = source.listen((rows) {
        latest = rows
            .map((row) {
              try {
                final value = row.value;
                return NoteEditorPresenceMapper.fromJson(value);
              } catch (_) {
                return null;
              }
            })
            .whereType<NoteEditorPresence>()
            .toList();
        controller.add(filterActive());
      }, onError: controller.addError);

      final ticker = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!controller.isClosed) {
          controller.add(filterActive());
        }
      });

      controller.onCancel = () {
        ticker.cancel();
        subscription.cancel();
      };
    });
  }

  Note _normalizeNote(Note note) {
    final normalizedTitle = note.title.trim().isEmpty
        ? 'Untitled Document'
        : note.title.trim();
    return note.copyWith(title: normalizedTitle);
  }

  String _documentKey(String documentId) =>
      '$_documentsPrefix${_encodeKeyPart(documentId)}';

  String _presenceKey(String documentId, String userId) =>
      '${_presencePrefixForDocument(documentId)}${_encodeKeyPart(userId)}';

  String _presencePrefixForDocument(String documentId) =>
      '$_presencePrefix${_encodeKeyPart(documentId)}:';

  String _encodeKeyPart(String value) => base64Url.encode(utf8.encode(value));
}
