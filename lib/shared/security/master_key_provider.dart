import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'encryption_service.dart';

abstract class MasterKeyProvider {
  Future<SecretKey> getMasterKey();
}

class DeviceDerivedMasterKeyProvider implements MasterKeyProvider {
  static const String _installIdKey = 'cohrtz_secure_install_id';
  static const String _saltKey = 'cohrtz_secure_kdf_salt';
  static const String _namespace = 'cohrtz_secure_storage_v1';

  final EncryptionService _encryptionService;
  final Future<SharedPreferences> Function() _prefsFactory;

  SecretKey? _cachedKey;
  Future<SecretKey>? _inFlight;

  DeviceDerivedMasterKeyProvider({
    EncryptionService? encryptionService,
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _encryptionService = encryptionService ?? EncryptionService(),
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  @override
  Future<SecretKey> getMasterKey() async {
    if (_cachedKey != null) return _cachedKey!;
    if (_inFlight != null) return _inFlight!;

    final future = _deriveInternal();
    _inFlight = future;

    try {
      final key = await future;
      _cachedKey = key;
      return key;
    } finally {
      _inFlight = null;
    }
  }

  Future<SecretKey> _deriveInternal() async {
    final prefs = await _prefsFactory();

    var installId = prefs.getString(_installIdKey);
    if (installId == null || installId.isEmpty) {
      installId = const Uuid().v4();
      await prefs.setString(_installIdKey, installId);
    }

    var saltB64 = prefs.getString(_saltKey);
    if (saltB64 == null || saltB64.isEmpty) {
      final salt = await _encryptionService.generateSalt();
      saltB64 = base64Encode(salt);
      await prefs.setString(_saltKey, saltB64);
    }
    final salt = base64Decode(saltB64);

    final passwordMaterial = '$installId|$_namespace|${_platformTag()}';
    return _encryptionService.deriveKeyFromPassword(passwordMaterial, salt);
  }

  String _platformTag() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
