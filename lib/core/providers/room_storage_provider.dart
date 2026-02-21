import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Providers
import 'crdt_provider.dart';
import 'packet_store_provider.dart';
import '../../features/dashboard/data/dashboard_repository.dart';

// I need to check if `localDashboardStorageProvider` was in the original `providers.dart`.
// Checking my read of `providers.dart`.
// Line 1213: final localDashboardStorageProvider = ref.watch(localDashboardStorageProvider);
// I missed `localDashboardStorageProvider` in my extraction list!
// I need to check where it is defined.
// Ah, line 1213 says `ref.watch(localDashboardStorageProvider)`. It implies it is defined somewhere.
// In the original file read (lines 1000+), I don't see `localDashboardStorageProvider` definition.
// Let me grep for it in `providers.dart` or imports.
// It might be imported from `dashboard_repository.dart` or similar?
// But `providers.dart` usually *defines* these.
// Maybe I missed it in my read. I viewed lines 1-800 and 801-1254.
// Let me quickly check the file content I have locally in memory.
// I don't see `localDashboardStorageProvider` definition in lines 1-1254 of the output I got.
// It is used in `roomStorageBreakdownProvider`.
// It must be defined in `providers.dart` or imported.
// If it is imported, then I need to import it here.
// Assuming it is remaining in `providers.dart` or I missed it.

// Wait, I am moving *everything* from `providers.dart` that is a provider.
// If `localDashboardStorageProvider` is in `providers.dart`, I should have moved it.
// If it's not there, it must be imported.
// In `app/lib/core/providers.dart`, checking imports...
// `import '../features/dashboard/data/dashboard_repository.dart';`
// Maybe it's there?

// Strategy: I will assume it's available via `import '../providers.dart';` for now, assuming I might have missed moving it or it's external.
// If I missed moving it, it will stay in `providers.dart` (because I will overwrite `providers.dart` with exports).
// Wait, if I overwrite `providers.dart` with only exports, and I missed moving `localDashboardStorageProvider`, it will be DELETED.
// THIS IS CRITICAL.
// I need to find `localDashboardStorageProvider` definition before I overwrite `providers.dart`.

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
