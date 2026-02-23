import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'encrypted_envelope_codec.dart';
import 'encryption_service.dart';
import 'master_key_provider.dart';
import 'secure_kv_backend.dart';
import 'secure_kv_backend_factory.dart';

abstract class ISecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
  Future<void> deleteAll();
  bool get isSecure;
}

class SecureStorageService implements ISecureStore {
  final SecureKvBackend _backend;
  final MasterKeyProvider _masterKeyProvider;
  final EncryptionService _encryptionService;

  SecretKey? _masterKey;
  Future<void>? _initializationFuture;
  bool _initializedSecurely = false;

  SecureStorageService({
    SecureKvBackend? backend,
    MasterKeyProvider? masterKeyProvider,
    EncryptionService? encryptionService,
  }) : _backend = backend ?? createSecureKvBackend(),
       _masterKeyProvider =
           masterKeyProvider ?? DeviceDerivedMasterKeyProvider(),
       _encryptionService = encryptionService ?? EncryptionService();

  Future<void> _ensureInitialized() async {
    if (_masterKey != null) return;
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
    await _backend.initialize();
    _masterKey = await _masterKeyProvider.getMasterKey();
    _initializedSecurely = true;
  }

  @override
  Future<String?> read(String key) async {
    await _ensureInitialized();
    final raw = await _backend.read(key);
    if (raw == null) return null;

    try {
      final encryptedBlob = EncryptedEnvelopeCodec.decode(raw);
      final decrypted = await _encryptionService.decrypt(
        encryptedBlob,
        _masterKey!,
        silent: true,
      );
      return utf8.decode(decrypted);
    } catch (e) {
      throw StateError('Failed to decrypt secure key "$key": $e');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _ensureInitialized();
    final encrypted = await _encryptionService.encrypt(
      utf8.encode(value),
      _masterKey!,
    );
    final encoded = EncryptedEnvelopeCodec.encode(encrypted);
    await _backend.write(key, encoded);
  }

  @override
  Future<void> delete(String key) async {
    await _ensureInitialized();
    await _backend.delete(key);
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureInitialized();
    return _backend.containsKey(key);
  }

  @override
  Future<void> deleteAll() async {
    await _ensureInitialized();
    await _backend.deleteAll();
  }

  @override
  bool get isSecure => _initializedSecurely;
}
