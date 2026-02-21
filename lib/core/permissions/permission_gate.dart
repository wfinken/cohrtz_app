import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_providers.dart';
import 'permission_utils.dart';

class PermissionGate extends ConsumerWidget {
  final int permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    return permissionsAsync.when(
      data: (permissions) {
        if (PermissionUtils.has(permissions, permission)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () => fallback ?? const SizedBox.shrink(),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
    );
  }
}
