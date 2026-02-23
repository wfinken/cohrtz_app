import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'secure_kv_backend.dart';

class WebSecurePrefsBackend implements SecureKvBackend {
  static const String _prefix = 'secure_blob_';

  Future<void>? _initializationFuture;
  SharedPreferences? _prefs;

  @override
  Future<void> initialize() async {
    if (_prefs != null) return;
    if (_initializationFuture != null) return _initializationFuture!;
    final future = _initializeInternal();
    _initializationFuture = future;
    try {
      await future;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<Uint8List?> read(String key) async {
    await initialize();
    final encoded = _prefs!.getString('$_prefix$key');
    if (encoded == null || encoded.isEmpty) return null;
    return Uint8List.fromList(base64Decode(encoded));
  }

  @override
  Future<void> write(String key, Uint8List value) async {
    await initialize();
    await _prefs!.setString('$_prefix$key', base64Encode(value));
  }

  @override
  Future<void> delete(String key) async {
    await initialize();
    await _prefs!.remove('$_prefix$key');
  }

  @override
  Future<bool> containsKey(String key) async {
    await initialize();
    return _prefs!.containsKey('$_prefix$key');
  }

  @override
  Future<void> deleteAll() async {
    await initialize();
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
}
