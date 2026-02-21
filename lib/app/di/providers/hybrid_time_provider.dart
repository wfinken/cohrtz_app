import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/slices/sync/runtime/hybrid_time_service.dart';
import 'node_id_provider.dart';

final hybridTimeServiceProvider = Provider<HybridTimeService>((ref) {
  return HybridTimeService(
    getLocalParticipantId: () => ref.read(nodeIdProvider),
  );
});
