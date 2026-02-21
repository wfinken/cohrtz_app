import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_models.dart';

// Provides a map of threadId -> unreadCount
final unreadMessagesProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final groupId = repo.currentRoomName;

  if (groupId == null) return const AsyncValue.data({});

  final messagesAsync = ref.watch(allMessagesProvider);
  final readStatusAsync = ref.watch(readStatusStreamProvider(groupId));

  return messagesAsync.when(
    data: (messages) {
      return readStatusAsync.when(
        data: (readStatus) {
          final unreadCounts = <String, int>{};

          for (final msg in messages) {
            final lastRead = readStatus[msg.threadId] ?? 0;
            if (msg.timestamp.millisecondsSinceEpoch > lastRead) {
              unreadCounts[msg.threadId] =
                  (unreadCounts[msg.threadId] ?? 0) + 1;
            }
          }

          return AsyncValue.data(unreadCounts);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

final allMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchMessages();
});

final readStatusStreamProvider =
    StreamProvider.family<Map<String, int>, String>((ref, groupId) {
      final storage = ref.watch(localDashboardStorageProvider);
      return storage.watchReadStatus(groupId);
    });

final totalUnreadCountProvider = Provider<int>((ref) {
  final unreadMapAsync = ref.watch(unreadMessagesProvider);
  return unreadMapAsync.maybeWhen(
    data: (map) => map.values.fold(0, (sum, count) => sum + count),
    orElse: () => 0,
  );
});
