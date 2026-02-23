import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import 'secure_storage_service.dart';

/// Security service for cryptographic operations.
/// Uses secure storage for private keys (hardware-backed on native platforms).
class SecurityService {
  final _algorithm = Ed25519();
  final _keyExchangeAlgorithm = X25519();
  final ISecureStore _secureStorage;
  static const String _globalGroupId = '__cohrtz_global__';

  final Map<String, SimpleKeyPair> _signingKeyPairs = {};
  final Map<String, SimpleKeyPair> _encryptionKeyPairs = {};
  final Map<String, Future<void>> _initializationFutures = {};

  SecurityService({ISecureStore? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorageService();

  Future<void> initialize() async {
    await _ensureInitialized(_globalGroupId, legacyStorageKeys: true);
  }

  /// Initializes (loads or generates) a signing key pair and encryption key pair
  /// for the given [groupId].
  ///
  /// This ensures public/secret keys are generated per group/room rather than
  /// reusing a single global identity across all rooms.
  Future<void> initializeForGroup(String groupId) async {
    if (groupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Must not be empty');
    }
    await _ensureInitialized(groupId, legacyStorageKeys: false);
  }

  Future<void> _ensureInitialized(
    String groupId, {
    required bool legacyStorageKeys,
  }) async {
    final initKey = '${legacyStorageKeys ? "legacy" : "group"}:$groupId';
    final existing = _initializationFutures[initKey];
    if (existing != null) return existing;

    final future = _initializeInternal(
      groupId,
      legacyStorageKeys: legacyStorageKeys,
    );
    _initializationFutures[initKey] = future;
    return future;
  }

  String _signingSeedStorageKey(
    String groupId, {
    required bool legacyStorageKeys,
  }) {
    return legacyStorageKeys ? 'cohrtz_key_seed' : 'cohrtz_key_seed_$groupId';
  }

  String _encryptionSeedStorageKey(
    String groupId, {
    required bool legacyStorageKeys,
  }) {
    return legacyStorageKeys
        ? 'cohrtz_encryption_key_seed'
        : 'cohrtz_encryption_key_seed_$groupId';
  }

  Future<void> _initializeInternal(
    String groupId, {
    required bool legacyStorageKeys,
  }) async {
    // 1) Signing keypair (Ed25519)
    final signingSeedKey = _signingSeedStorageKey(
      groupId,
      legacyStorageKeys: legacyStorageKeys,
    );
    final savedSigningSeed = await _secureStorage.read(signingSeedKey);

    if (savedSigningSeed != null) {
      final seed = base64Decode(savedSigningSeed);
      _signingKeyPairs[groupId] = await _algorithm.newKeyPairFromSeed(seed);
      Log.i(
        'SecurityService',
        'Loaded existing Ed25519 key pair (groupId: $groupId).',
      );
    } else {
      final keyPair = await _algorithm.newKeyPair();
      final seed = await keyPair.extractPrivateKeyBytes();
      await _secureStorage.write(signingSeedKey, base64Encode(seed));
      _signingKeyPairs[groupId] = keyPair;
      Log.i(
        'SecurityService',
        'Generated and saved new Ed25519 key pair (groupId: $groupId).',
      );
    }

    // 2) Encryption keypair (X25519)
    final encryptionSeedKey = _encryptionSeedStorageKey(
      groupId,
      legacyStorageKeys: legacyStorageKeys,
    );
    final savedEncryptionSeed = await _secureStorage.read(encryptionSeedKey);

    if (savedEncryptionSeed != null) {
      final seed = base64Decode(savedEncryptionSeed);
      _encryptionKeyPairs[groupId] = await _keyExchangeAlgorithm
          .newKeyPairFromSeed(seed);
      Log.i(
        'SecurityService',
        'Loaded existing X25519 key pair (groupId: $groupId).',
      );
    } else {
      final keyPair = await _keyExchangeAlgorithm.newKeyPair();
      final seed = await keyPair.extractPrivateKeyBytes();
      await _secureStorage.write(encryptionSeedKey, base64Encode(seed));
      _encryptionKeyPairs[groupId] = keyPair;
      Log.i(
        'SecurityService',
        'Generated and saved new X25519 key pair (groupId: $groupId).',
      );
    }

    final pubKey = await _signingKeyPairs[groupId]!.extractPublicKey();
    Log.i(
      'SecurityService',
      'Initialized (groupId: $groupId) with Public Key: ${pubKey.bytes.length} bytes',
    );

    if (!_secureStorage.isSecure) {
      Log.w(
        'SecurityService',
        '⚠️ WARNING: Running in insecure mode (web). Keys stored in SharedPreferences.',
      );
    }
  }

  Future<SimpleKeyPair> _getSigningKeyPair({String? groupId}) async {
    final effectiveGroupId = groupId ?? _globalGroupId;
    if (groupId == null) {
      await initialize();
    } else {
      await initializeForGroup(groupId);
    }

    final kp = _signingKeyPairs[effectiveGroupId];
    if (kp == null) {
      throw StateError('Signing keypair not available for $effectiveGroupId');
    }
    return kp;
  }

  Future<SimpleKeyPair> _getEncryptionKeyPair({String? groupId}) async {
    final effectiveGroupId = groupId ?? _globalGroupId;
    if (groupId == null) {
      await initialize();
    } else {
      await initializeForGroup(groupId);
    }

    final kp = _encryptionKeyPairs[effectiveGroupId];
    if (kp == null) {
      throw StateError(
        'Encryption keypair not available for $effectiveGroupId',
      );
    }
    return kp;
  }

  Future<List<int>> sign(List<int> message, {String? groupId}) async {
    final signingKeyPair = await _getSigningKeyPair(groupId: groupId);

    final signature = await _algorithm.sign(message, keyPair: signingKeyPair);

    return signature.bytes;
  }

  /// Signs a P2PPacket by hashing its critical fields.
  /// The signature is stored in the packet's signature field.
  Future<void> signPacket(dynamic packet, {String? groupId}) async {
    final signingKeyPair = await _getSigningKeyPair(groupId: groupId);

    // We must ensure the packet has the required fields
    // Using dynamic to avoid strict protobuf dependency here if needed,
    // but in this project we can assume it's a P2PPacket.
    final dataToSign = _getPacketSigningData(packet);
    final signature = await _algorithm.sign(
      dataToSign,
      keyPair: signingKeyPair,
    );
    packet.signature = signature.bytes;

    // Only set senderPublicKey if it hasn't been explicitly set (e.g., TreeKEM keys)
    if (!packet.hasSenderPublicKey() || packet.senderPublicKey.isEmpty) {
      packet.senderPublicKey = await getPublicKey(groupId: groupId);
    }
  }

  Future<bool> verify(
    List<int> message,
    List<int> signatureBytes,
    List<int> publicKeyBytes,
  ) async {
    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final signature = Signature(signatureBytes, publicKey: publicKey);

    return await _algorithm.verify(message, signature: signature);
  }

  /// Verifies a P2PPacket's signature.
  /// If [publicKeyOverride] is provided, it uses that for verification.
  /// Otherwise, it uses the senderPublicKey from the packet.
  Future<bool> verifyPacket(
    dynamic packet, {
    List<int>? publicKeyOverride,
  }) async {
    final pubKeyBytes = publicKeyOverride ?? packet.senderPublicKey;
    if (pubKeyBytes == null || pubKeyBytes.isEmpty) {
      Log.w('SecurityService', 'Verification failed: No public key available');
      return false;
    }

    if (packet.signature.isEmpty) {
      Log.w('SecurityService', 'Verification failed: No signature on packet');
      return false;
    }

    final dataToVerify = _getPacketSigningData(packet);
    final publicKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);
    final signature = Signature(packet.signature, publicKey: publicKey);

    return await _algorithm.verify(dataToVerify, signature: signature);
  }

  /// Extracts the fields that should be signed from a packet.
  /// Returns a deterministic byte array.
  List<int> _getPacketSigningData(dynamic packet) {
    // Protocol versioning or domain separation could be added here
    final builder = BytesBuilder();

    // Sign critical fields
    builder.addByte(packet.type.value);
    builder.add(utf8.encode(packet.requestId));
    builder.add(utf8.encode(packet.senderId));
    builder.add(packet.payload);

    // Hybrid time fields (int64 little-endian).
    int physical = 0;
    int logical = 0;
    try {
      if (packet.hasPhysicalTime()) {
        physical = packet.physicalTime.toInt();
      }
      if (packet.hasLogicalTime()) {
        logical = packet.logicalTime.toInt();
      }
    } catch (_) {
      // Backward-compatible: ignore if the packet type doesn't support these fields.
    }
    builder.add(_int64ToLittleEndianBytes(physical));
    builder.add(_int64ToLittleEndianBytes(logical));

    // Optional fields
    // For integers, we use a 4-byte little-endian representation to be deterministic
    final chunkBuf = ByteData(4)..setInt32(0, packet.chunkIndex, Endian.little);
    builder.add(chunkBuf.buffer.asUint8List());

    builder.addByte(packet.isLastChunk ? 1 : 0);
    builder.add(utf8.encode(packet.targetId));
    builder.addByte(packet.encrypted ? 1 : 0);

    return builder.takeBytes();
  }

  // ByteData.setInt64/getInt64 are unsupported on dart2js.
  // Encode signed int64 manually in little-endian so signatures are stable
  // across native and web runtimes.
  Uint8List _int64ToLittleEndianBytes(int value) {
    final bytes = Uint8List(8);
    var v = BigInt.from(value);
    final mod64 = BigInt.one << 64;
    if (v.isNegative) {
      v += mod64;
    }

    for (var i = 0; i < 8; i++) {
      bytes[i] = (v & BigInt.from(0xFF)).toInt();
      v = v >> 8;
    }

    return bytes;
  }

  Future<List<int>> getPublicKey({String? groupId}) async {
    final signingKeyPair = await _getSigningKeyPair(groupId: groupId);
    final pub = await signingKeyPair.extractPublicKey();
    return pub.bytes;
  }

  Future<List<int>> getEncryptionPublicKey({String? groupId}) async {
    final encryptionKeyPair = await _getEncryptionKeyPair(groupId: groupId);
    final pub = await encryptionKeyPair.extractPublicKey();
    return pub.bytes;
  }

  /// Clears and regenerates signing/encryption keypairs for a specific group.
  /// This is used when users explicitly rotate their keys for one group.
  Future<void> resetGroupKeys(String groupId) async {
    if (groupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Must not be empty');
    }

    await _secureStorage.delete(
      _signingSeedStorageKey(groupId, legacyStorageKeys: false),
    );
    await _secureStorage.delete(
      _encryptionSeedStorageKey(groupId, legacyStorageKeys: false),
    );

    _signingKeyPairs.remove(groupId);
    _encryptionKeyPairs.remove(groupId);
    _initializationFutures.remove('group:$groupId');

    await initializeForGroup(groupId);
  }

  /// Returns the deterministic seed for the encryption key pair.
  /// Used as a base for TreeKEM leaf secrets to ensure consistency.
  Future<List<int>> getEncryptionSeed({String? groupId}) async {
    final effectiveGroupId = groupId ?? _globalGroupId;
    if (groupId == null) {
      await initialize();
    } else {
      await initializeForGroup(groupId);
    }

    final savedSeed = await _secureStorage.read(
      _encryptionSeedStorageKey(
        effectiveGroupId,
        legacyStorageKeys: groupId == null,
      ),
    );
    if (savedSeed == null) {
      throw StateError('Encryption key seed not found');
    }
    return base64Decode(savedSeed);
  }

  /// Returns the X25519 encryption key pair.
  /// Used by TreeKEM for WELCOME message decryption.
  Future<SimpleKeyPair> getEncryptionKeyPair({String? groupId}) async {
    return _getEncryptionKeyPair(groupId: groupId);
  }

  /// Derives a shared secret using our Private Key and the remote Public Key.
  /// Returns a 32-byte shared secret (suitable for AES-GCM-256).
  Future<SecretKey> deriveSharedSecret(
    List<int> remotePublicKeyBytes, {
    List<int>? salt,
    String? groupId,
  }) async {
    final encryptionKeyPair = await _getEncryptionKeyPair(groupId: groupId);

    final remotePublicKey = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchangeAlgorithm.sharedSecretKey(
      keyPair: encryptionKeyPair,
      remotePublicKey: remotePublicKey,
    );

    // HKDF-like derivation using SHA-256
    final sharedSecretBytes = await sharedSecret.extractBytes();
    final hashAlgorithm = Sha256();
    final input = [...sharedSecretBytes, ...(salt ?? <int>[])];
    final hash = await hashAlgorithm.hash(input);

    return SecretKey(hash.bytes);
  }
}
