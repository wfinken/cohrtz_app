import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/secure_storage_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
