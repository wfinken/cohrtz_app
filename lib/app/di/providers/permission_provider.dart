import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/permissions_core/permission_service.dart';
import 'crdt_provider.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref.watch(crdtServiceProvider));
});
