import 'secure_kv_backend.dart';
import 'web_secure_prefs_backend.dart';

SecureKvBackend createPlatformSecureKvBackend() => WebSecurePrefsBackend();
