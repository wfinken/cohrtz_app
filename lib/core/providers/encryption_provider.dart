import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/encryption_service.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});
