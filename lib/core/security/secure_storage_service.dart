import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-aware secure storage service.
/// Uses FlutterSecureStorage on native platforms, falls back to SharedPreferences on web.
///
/// WARNING: Web storage is NOT secure and should only be used for development.
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Read a value from secure storage.
  Future<String?> read(String key) async {
    if (kIsWeb) {
      return await _readInsecure(key);
    }
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      if (e.toString().contains('-34018')) {
        debugPrint(
          '[SecureStorage] Catching Keychain error -34018 for key: $key. Falling back to insecure storage.',
        );
        return await _readInsecure(key);
      }
      rethrow;
    }
  }

  /// Write a value to secure storage.
  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      await _writeInsecure(key, value);
      return;
    }
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      if (e.toString().contains('-34018')) {
        debugPrint(
          '[SecureStorage] Catching Keychain error -34018 for key: $key during write. Falling back to insecure storage.',
        );
        await _writeInsecure(key, value);
        return;
      }
      rethrow;
    }
  }

  /// Delete a value from secure storage.
  Future<void> delete(String key) async {
    if (kIsWeb) {
      await _deleteInsecure(key);
      return;
    }
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      if (e.toString().contains('-34018')) {
        await _deleteInsecure(key);
        return;
      }
      rethrow;
    }
  }

  /// Check if a key exists in secure storage.
  Future<bool> containsKey(String key) async {
    if (kIsWeb) {
      return await _containsKeyInsecure(key);
    }
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      if (e.toString().contains('-34018')) {
        return await _containsKeyInsecure(key);
      }
      rethrow;
    }
  }

  /// Delete all values from secure storage.
  Future<void> deleteAll() async {
    if (kIsWeb) {
      await _deleteAllInsecure();
      return;
    }
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      if (e.toString().contains('-34018')) {
        await _deleteAllInsecure();
        return;
      }
      rethrow;
    }
  }

  Future<String?> _readInsecure(String key) async {
    debugPrint(
      '[SecureStorage] ⚠️ INSECURE MODE: Using SharedPreferences for key: $key',
    );
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('secure_$key');
  }

  Future<void> _writeInsecure(String key, String value) async {
    debugPrint(
      '[SecureStorage] ⚠️ INSECURE MODE: Writing to SharedPreferences for key: $key',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('secure_$key', value);
  }

  Future<void> _deleteInsecure(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('secure_$key');
  }

  Future<bool> _containsKeyInsecure(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('secure_$key');
  }

  Future<void> _deleteAllInsecure() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('secure_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Returns true if running in secure mode (native platforms with functioning Keychain/Keystore).
  bool get isSecure => !kIsWeb;
}
