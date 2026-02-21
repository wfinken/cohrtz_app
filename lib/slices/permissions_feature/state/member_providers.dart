import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/member_repository.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  final currentRoomName = ref.watch(
    syncServiceProvider.select((s) => s.currentRoomName),
  );
  return MemberRepository(ref.read(crdtServiceProvider), currentRoomName);
});

final membersProvider = StreamProvider<List<GroupMember>>((ref) {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.watchMembers();
});
