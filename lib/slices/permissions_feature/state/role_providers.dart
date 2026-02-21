import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/role_repository.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';

final roleRepositoryProvider = Provider<RoleRepository>((ref) {
  final currentRoomName = ref.watch(
    syncServiceProvider.select((s) => s.currentRoomName),
  );
  return RoleRepository(ref.read(crdtServiceProvider), currentRoomName);
});

final rolesProvider = StreamProvider<List<Role>>((ref) {
  final repo = ref.watch(roleRepositoryProvider);
  return repo.watchRoles();
});
