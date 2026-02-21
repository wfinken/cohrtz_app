import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/core/providers.dart';
import 'package:cohortz/features/permissions/data/member_repository.dart';
import 'package:cohortz/features/permissions/domain/member_model.dart';

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
