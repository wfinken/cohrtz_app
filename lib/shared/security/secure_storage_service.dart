import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ISecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
  Future<void> deleteAll();
  bool get isSecure;
}

/// Platform-aware secure storage service.
/// Uses FlutterSecureStorage on native platforms, falls back to SharedPreferences on web.
///
/// WARNING: Web storage is NOT secure and should only be used for development.
class SecureStorageService implements ISecureStore {
  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> Function() _prefsFactory;

  SecureStorageService({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
             mOptions: MacOsOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           ),
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  /// Read a value from secure storage.
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
    final prefs = await _prefsFactory();
    return prefs.getString('secure_$key');
  }

  Future<void> _writeInsecure(String key, String value) async {
    debugPrint(
      '[SecureStorage] ⚠️ INSECURE MODE: Writing to SharedPreferences for key: $key',
    );
    final prefs = await _prefsFactory();
    await prefs.setString('secure_$key', value);
  }

  Future<void> _deleteInsecure(String key) async {
    final prefs = await _prefsFactory();
    await prefs.remove('secure_$key');
  }

  Future<bool> _containsKeyInsecure(String key) async {
    final prefs = await _prefsFactory();
    return prefs.containsKey('secure_$key');
  }

  Future<void> _deleteAllInsecure() async {
    final prefs = await _prefsFactory();
    final keys = prefs.getKeys().where((k) => k.startsWith('secure_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Returns true if running in secure mode (native platforms with functioning Keychain/Keystore).
  @override
  bool get isSecure => !kIsWeb;
}
