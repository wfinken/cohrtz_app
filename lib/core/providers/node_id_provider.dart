import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'identity_provider.dart';

final nodeIdProvider = Provider<String>((ref) {
  final identity = ref.watch(identityServiceProvider);
  final id = identity.profile?.id;
  if (id == null) {
    // 'anonymous' is dangerous for CRDTs as it can cause collisions across different users.
    // If we're here, it means we're accessing nodeId before IdentityService is fully ready.
    final fallback = 'unknown_session_${const Uuid().v4()}';
    debugPrint(
      '[nodeIdProvider] WARNING: Identity not ready. Using transient fallback: $fallback',
    );
    return fallback;
  }
  return id;
});
