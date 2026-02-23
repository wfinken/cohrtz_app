import 'secure_kv_backend.dart';
import 'secure_kv_backend_factory_native.dart'
    if (dart.library.html) 'secure_kv_backend_factory_web.dart';

SecureKvBackend createSecureKvBackend() => createPlatformSecureKvBackend();
