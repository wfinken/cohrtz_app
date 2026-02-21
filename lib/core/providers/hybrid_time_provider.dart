import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync/infrastructure/hybrid_time_service.dart';
import 'node_id_provider.dart';

final hybridTimeServiceProvider = Provider<HybridTimeService>((ref) {
  return HybridTimeService(
    getLocalParticipantId: () => ref.read(nodeIdProvider),
  );
});
