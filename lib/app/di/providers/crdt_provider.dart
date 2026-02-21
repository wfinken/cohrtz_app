import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

final crdtServiceProvider = Provider<CrdtService>((ref) {
  return CrdtService();
});
