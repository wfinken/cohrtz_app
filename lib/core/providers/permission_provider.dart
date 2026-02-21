import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../permissions/permission_service.dart';
import 'crdt_provider.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref.watch(crdtServiceProvider));
});
