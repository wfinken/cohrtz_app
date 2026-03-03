import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'crdt_provider.dart';
import 'packet_store_provider.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';

class RoomStorageBreakdown {
  final int crdtBytes;
  final int dashboardBytes;
  final int packetStoreBytes;

  const RoomStorageBreakdown({
    required this.crdtBytes,
    required this.dashboardBytes,
    required this.packetStoreBytes,
  });

  int get totalBytes => crdtBytes + dashboardBytes + packetStoreBytes;
}

final roomStorageBreakdownProvider =
    FutureProvider.family<RoomStorageBreakdown, String>((ref, roomName) async {
      if (roomName.isEmpty) {
        return const RoomStorageBreakdown(
          crdtBytes: 0,
          dashboardBytes: 0,
          packetStoreBytes: 0,
        );
      }

      final crdtService = ref.watch(crdtServiceProvider);

      final localDashboardStorage = ref.watch(localDashboardStorageProvider);
      final packetStore = ref.watch(packetStoreProvider);

      int crdtBytes = 0;
      int dashboardBytes = 0;
      int packetStoreBytes = 0;

      try {
        crdtBytes = await crdtService.getDatabaseSize(roomName);
      } catch (e) {
        debugPrint('[roomStorageProvider] CRDT size error: $e');
      }

      try {
        dashboardBytes = await localDashboardStorage.getStorageSize(roomName);
      } catch (e) {
        debugPrint('[roomStorageProvider] Dashboard storage error: $e');
      }

      try {
        packetStoreBytes = await packetStore.getStorageSize(roomName);
      } catch (e) {
        debugPrint('[roomStorageProvider] Packet store size error: $e');
      }

      return RoomStorageBreakdown(
        crdtBytes: crdtBytes,
        dashboardBytes: dashboardBytes,
        packetStoreBytes: packetStoreBytes,
      );
    });

final roomStorageProvider = FutureProvider.family<int, String>((
  ref,
  roomName,
) async {
  final breakdown = await ref.watch(
    roomStorageBreakdownProvider(roomName).future,
  );
  return breakdown.totalBytes;
});
