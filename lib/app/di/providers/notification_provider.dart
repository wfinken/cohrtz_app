import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/notifications/app_notification_service.dart';
import 'package:cohortz/app/di/providers/secure_storage_provider.dart';

final notificationServiceProvider = Provider<AppNotificationService>((ref) {
  final secureStorage = ref.read(secureStorageServiceProvider);
  final service = AppNotificationService(secureStorage);

  // Listen to service changes and notify provider listeners
  void listener() => ref.notifyListeners();
  service.addListener(listener);

  ref.onDispose(() {
    service.removeListener(listener);
    service.dispose();
  });

  return service;
});
