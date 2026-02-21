import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/data/note_repository.dart';
import 'crdt_provider.dart';
import 'sync_service_provider.dart';
import 'hybrid_time_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final crdtService = ref.watch(crdtServiceProvider);
  final currentRoomName = ref.watch(
    syncServiceProvider.select((s) => s.currentRoomName),
  );
  return NoteRepository(
    crdtService,
    currentRoomName,
    ref.watch(hybridTimeServiceProvider),
  );
});
