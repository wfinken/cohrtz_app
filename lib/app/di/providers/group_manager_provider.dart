import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/runtime/group_manager.dart';
import 'secure_storage_provider.dart';

final groupManagerProvider = Provider<GroupManager>((ref) {
  return GroupManager(secureStorage: ref.watch(secureStorageServiceProvider));
});
