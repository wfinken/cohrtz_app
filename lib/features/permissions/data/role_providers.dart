import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/core/providers.dart';
import 'package:cohortz/features/permissions/data/role_repository.dart';
import 'package:cohortz/features/permissions/domain/role_model.dart';

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
