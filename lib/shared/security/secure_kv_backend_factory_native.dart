import 'native_sql_blob_backend.dart';
import 'secure_kv_backend.dart';

SecureKvBackend createPlatformSecureKvBackend() => NativeSqlBlobBackend();
