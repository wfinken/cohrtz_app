import 'dart:typed_data';

abstract class SecureKvBackend {
  Future<void> initialize();
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
  Future<void> deleteAll();
}
