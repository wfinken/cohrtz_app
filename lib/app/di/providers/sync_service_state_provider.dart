import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'sync_service_provider.dart';

@immutable
class SyncServiceState {
  const SyncServiceState({
    required this.currentRoomName,
    required this.identity,
    required this.isConnected,
    required this.isActiveRoomConnected,
    required this.isActiveRoomConnecting,
    required this.knownGroups,
    required this.remoteParticipants,
  });

  final String? currentRoomName;
  final String? identity;
  final bool isConnected;
  final bool isActiveRoomConnected;
  final bool isActiveRoomConnecting;
  final List<Map<String, String?>> knownGroups;
  final Map<String, RemoteParticipant> remoteParticipants;
}

final syncServiceStateProvider = Provider<SyncServiceState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return SyncServiceState(
    currentRoomName: syncService.currentRoomName,
    identity: syncService.identity,
    isConnected: syncService.isConnected,
    isActiveRoomConnected: syncService.isActiveRoomConnected,
    isActiveRoomConnecting: syncService.isActiveRoomConnecting,
    knownGroups: List<Map<String, String?>>.from(syncService.knownGroups),
    remoteParticipants: Map<String, RemoteParticipant>.from(
      syncService.remoteParticipants,
    ),
  );
});
