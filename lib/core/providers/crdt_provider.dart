import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sync/infrastructure/crdt_service.dart';

final crdtServiceProvider = Provider<CrdtService>((ref) {
  return CrdtService();
});
