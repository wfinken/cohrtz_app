import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/shared/security/identity_service.dart';

final identityServiceProvider = Provider<IdentityService>((ref) {
  final service = IdentityService();
  void listener() => ref.notifyListeners();
  service.addListener(listener);
  ref.onDispose(() {
    service.removeListener(listener);
    service.dispose();
  });
  return service;
});
