import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/notes/models/note_model.dart';
import 'sync_service_provider.dart';
import 'note_repository_provider.dart';

final notesListProvider = StreamProvider<List<Note>>((ref) {
  ref.watch(syncServiceProvider.select((s) => s.currentRoomName));
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchNotes();
});
