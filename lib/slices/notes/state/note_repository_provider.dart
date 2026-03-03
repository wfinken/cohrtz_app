import 'package:cohortz/app/di/providers/crdt_provider.dart';
import 'package:cohortz/app/di/providers/hybrid_time_provider.dart';
import 'package:cohortz/app/di/providers/sync_service_provider.dart';
import 'package:cohortz/slices/notes/state/note_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
