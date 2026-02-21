import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_service_provider.dart';

/// Provider for the set of currently connected participant identities.
final connectedParticipantIdentitiesProvider = Provider<Set<String>>((ref) {
  // Watch SyncService for reactivity (which proxies ConnectionManager events)
  ref.watch(syncServiceProvider);
  final sync = ref.read(syncServiceProvider);

  final activeRoom = sync.activeRoomName;
  if (activeRoom == null) return {};

  final participants = sync.remoteParticipants;
  final identities = participants.values
      .map((p) => p.identity)
      .whereType<String>()
      .toSet();

  final myId = sync.localParticipantId;
  if (myId != null) identities.add(myId);

  return identities;
});
