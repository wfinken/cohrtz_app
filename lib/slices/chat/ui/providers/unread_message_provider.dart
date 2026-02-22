import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';

// Provides a map of threadId -> unreadCount
final unreadMessagesProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final groupId = repo.currentRoomName;

  if (groupId == null) return const AsyncValue.data({});

  final messagesAsync = ref.watch(allMessagesProvider);
  final readStatusAsync = ref.watch(readStatusStreamProvider(groupId));
  final threadsAsync = ref.watch(allThreadsProvider);
  final myGroupIds = ref.watch(myLogicalGroupIdsProvider);
  final isOwner = ref.watch(currentUserIsOwnerProvider);
  final permissions = ref.watch(currentUserPermissionsProvider).value;
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));

  return messagesAsync.when(
    data: (messages) {
      return threadsAsync.when(
        data: (threads) {
          final visibleThreadIds = <String>{ChatThread.generalId};
          for (final thread in threads) {
            if (thread.isDm ||
                canViewByLogicalGroups(
                  itemGroupIds: thread.visibilityGroupIds,
                  viewerGroupIds: myGroupIds,
                  bypass: bypass,
                )) {
              visibleThreadIds.add(thread.id);
            }
          }

          return readStatusAsync.when(
            data: (readStatus) {
              final unreadCounts = <String, int>{};

              for (final msg in messages) {
                if (!visibleThreadIds.contains(msg.threadId)) continue;
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
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

final allMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchMessages();
});

final allThreadsProvider = StreamProvider<List<ChatThread>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchChatThreads();
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
