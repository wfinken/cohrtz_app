import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';

import 'package:uuid/uuid.dart';

import '../../../shared/utils/logging_service.dart';

import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import '../../../shared/security/encryption_service.dart';
import '../../../shared/security/secure_storage_service.dart';
import 'treekem_handler.dart';

/// Manages Group Secret Keys (GSK) and Vault Keys for encrypted communication.
///
/// Extracted from SyncService for modularity and clearer responsibility.
class KeyManager {
  final EncryptionService _encryptionService;
  final SecureStorageService _secureStorage;
  final TreeKemHandler _treeKemHandler;
  final String Function(String roomName) getLocalParticipantIdForRoom;
  final Future<void> Function(String roomName, P2PPacket packet) broadcast;
  final Iterable<String> Function(String roomName)? getRemoteParticipantIds;
  final Future<void> Function(
    String roomName,
    String targetId,
    P2PPacket packet,
  )
  sendSecure;
  final int Function(String roomName) getRemoteParticipantCount;
  final bool Function(String roomName) isHost;

  /// In-memory cache of group keys by room name
  final Map<String, SecretKey> _groupKeys = {};

  /// Last time a GSK was requested for a room
  final Map<String, DateTime> _lastRequestTime = {};

  /// Completers for pending GSKs (RoomName -> Completer)
  final Map<String, Completer<SecretKey>> _gskCompleters = {};

  /// Completers for pending Vault Keys
  final Map<String, Completer<SecretKey>> _vaultKeyCompleters = {};

  KeyManager({
    required EncryptionService encryptionService,
    required SecureStorageService secureStorage,
    required TreeKemHandler treeKemHandler,
    required this.getLocalParticipantIdForRoom,
    required this.broadcast,
    this.getRemoteParticipantIds,
    required this.sendSecure,
    required this.getRemoteParticipantCount,
    required this.isHost,
  }) : _encryptionService = encryptionService,
       _secureStorage = secureStorage,
       _treeKemHandler = treeKemHandler;

  bool _isVaultKeyAuthority(String roomName) {
    if (isHost(roomName)) return true;
    final idsFn = getRemoteParticipantIds;
    if (idsFn == null) return false;

    final localId = getLocalParticipantIdForRoom(roomName);
    if (localId.isEmpty) return false;

    final all = <String>[
      localId,
      ...idsFn(roomName),
    ].where((id) => id.isNotEmpty).toSet().toList()..sort();

    return all.isNotEmpty && all.first == localId;
  }

  Future<void> _setVaultKey(String roomName, String keyStr) async {
    await _secureStorage.write('key_$roomName', keyStr);
    await _secureStorage.write('vault_key_initialized_$roomName', 'true');

    final completer = _vaultKeyCompleters[roomName];
    if (completer != null && !completer.isCompleted) {
      completer.complete(SecretKey(base64Decode(keyStr)));
      _vaultKeyCompleters.remove(roomName);
    }
  }

  Future<void> _shareVaultKeyToPeers(String roomName, String keyStr) async {
    final idsFn = getRemoteParticipantIds;
    if (idsFn == null) return;

    final peers = idsFn(roomName).where((id) => id.isNotEmpty).toSet();
    if (peers.isEmpty) return;

    for (final peerId in peers) {
      await _sendVaultKeyToPeer(roomName, peerId, keyStr);
    }
  }

  Future<void> _sendVaultKeyToPeer(
    String roomName,
    String targetId,
    String keyStr,
  ) async {
    final payload = utf8.encode(
      jsonEncode({'type': 'ROOM_KEY', 'key': keyStr}),
    );

    final packet = P2PPacket()
      ..type = P2PPacket_PacketType.UNICAST_REQ
      ..requestId = const Uuid().v4()
      ..senderId = getLocalParticipantIdForRoom(roomName)
      ..payload = payload;

    await sendSecure(roomName, targetId, packet);
  }

  /// Gets or generates the Group Secret Key (GSK) for a room.
  ///
  /// Priority order:
  /// 1. Memory cache
  /// 2. Secure storage
  /// 3. Generate if we're alone in the room
  /// 4. Request from peers if available
  Future<SecretKey> getGroupKey(
    String roomName, {
    bool allowWait = true,
  }) async {
    final tkService = _treeKemHandler.getService(roomName);
    if (tkService != null) {
      try {
        final tkSecret = await tkService.getGroupSecret();
        final tkKey = SecretKey(tkSecret);
        _groupKeys[roomName] = tkKey;
        return tkKey;
      } catch (e) {
        Log.w(
          'KeyManager',
          'Failed to get secret from active TreeKEM service: $e',
        );
      }
    }

    if (_groupKeys.containsKey(roomName)) return _groupKeys[roomName]!;

    // 2. Determine if we SHOULD use TreeKEM for this room.
    // If we have TreeKEM state on disk, we should NOT fallback to Legacy GSK.
    final hasTkState =
        await _secureStorage.read('treekem_private_$roomName') != null;

    final gskStr = await _secureStorage.read('gsk_$roomName');
    if (gskStr != null) {
      if (hasTkState) {
        Log.w(
          'KeyManager',
          'WARNING: Found TreeKEM state but Legacy GSK also exists for $roomName. Prioritizing TreeKEM (waiting for service).',
        );
      } else {
        final key = SecretKey(base64Decode(gskStr));
        _groupKeys[roomName] = key;
        Log.d('KeyManager', 'Using Legacy GSK for $roomName');
        return key;
      }
    }

    if (getRemoteParticipantCount(roomName) == 0 &&
        !hasTkState &&
        isHost(roomName)) {
      final key = await _generateAndSaveGroupKey(roomName);
      return key;
    }

    if (!allowWait) {
      // If we are not allowed to wait, we trigger the request if needed, but don't block.
      _requestGroupKey(roomName);
      throw StateError(
        'Group Secret Key not available immediately for $roomName',
      );
    }

    Log.i(
      'KeyManager',
      'GSK missing for $roomName (hasTkState: $hasTkState). Requesting and waiting...',
    );

    await _requestGroupKey(roomName);

    return _waitForGroupKey(roomName);
  }

  /// Waits for the Group Secret Key to be available.
  Future<SecretKey> _waitForGroupKey(String roomName) async {
    // Check if valid key exists now (race condition check)
    if (_groupKeys.containsKey(roomName)) return _groupKeys[roomName]!;

    final existing = _gskCompleters[roomName];
    final completer = (existing != null && !existing.isCompleted)
        ? existing
        : Completer<SecretKey>();
    final createdHere = existing == null || existing.isCompleted;
    if (createdHere) {
      _gskCompleters[roomName] = completer;
    }

    try {
      // Timeout after 30 seconds
      // This gives enough time for the Invite Handshake -> Data Room Transition -> Key Exchange
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (createdHere && _gskCompleters[roomName] == completer) {
            _gskCompleters.remove(roomName);
          }
          throw TimeoutException('Timed out waiting for GSK in $roomName');
        },
      );
    } catch (e) {
      throw StateError('Group Secret Key not available for $roomName: $e');
    }
  }

  /// Generates a new GSK and saves it.
  Future<SecretKey> _generateAndSaveGroupKey(String roomName) async {
    final key = await _encryptionService.generateKey();
    final bytes = await key.extractBytes();
    final keyStr = base64Encode(bytes);
    await _secureStorage.write('gsk_$roomName', keyStr);
    _groupKeys[roomName] = key;
    // Check if we have a pending waiter
    if (_gskCompleters.containsKey(roomName) &&
        !_gskCompleters[roomName]!.isCompleted) {
      _gskCompleters[roomName]!.complete(key);
      _gskCompleters.remove(roomName);
    }
    Log.d('KeyManager', 'Generated new Group Secret Key (GSK) for $roomName');
    return key;
  }

  /// Requests the GSK from peers in the room.
  Future<void> _requestGroupKey(String roomName, {bool force = false}) async {
    final now = DateTime.now();
    final last = _lastRequestTime[roomName];

    // Throttle requests to once every 2 seconds per room, unless forced.
    // Join flows can otherwise stall if an early request races before peers are
    // ready to share keys.
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(seconds: 2)) {
      return;
    }

    final senderId = getLocalParticipantIdForRoom(roomName);
    if (senderId.isEmpty) {
      Log.w(
        'KeyManager',
        'Skipping GSK_REQ for $roomName: local participant identity not ready.',
      );
      return;
    }

    final payload = utf8.encode(jsonEncode({'type': 'GSK_REQ'}));
    final packet = P2PPacket()
      ..type = P2PPacket_PacketType.UNICAST_REQ
      ..requestId = const Uuid().v4()
      ..senderId = senderId
      ..payload = payload;

    _lastRequestTime[roomName] = now;
    Log.d('KeyManager', 'Broadcasting GSK_REQ for $roomName');
    await broadcast(roomName, packet);
  }

  /// Shares our GSK with a specific peer if we have it.
  Future<void> shareGroupKeyIfHeld(String roomName, String targetId) async {
    SecretKey? key = _groupKeys[roomName];

    if (key == null) {
      final tkService = _treeKemHandler.getService(roomName);
      if (tkService != null) {
        try {
          final secret = await tkService.getGroupSecret();
          key = SecretKey(secret);
          _groupKeys[roomName] = key;
        } catch (_) {
          // Fall through to secure storage fallback.
        }
      }
    }

    String? gskStr;
    if (key != null) {
      gskStr = base64Encode(await key.extractBytes());
    } else {
      gskStr = await _secureStorage.read('gsk_$roomName');
      if (gskStr != null) {
        key = SecretKey(base64Decode(gskStr));
        _groupKeys[roomName] = key;
      }
    }

    if (gskStr == null) return;

    Log.d('KeyManager', 'Sharing GSK with $targetId in $roomName');
    final payload = utf8.encode(
      jsonEncode({'type': 'GSK_SHARE', 'key': gskStr}),
    );

    final packet = P2PPacket()
      ..type = P2PPacket_PacketType.UNICAST_REQ
      ..requestId = const Uuid().v4()
      ..senderId = getLocalParticipantIdForRoom(roomName)
      ..payload = payload;

    await sendSecure(roomName, targetId, packet);
  }

  /// Handles receiving a shared GSK.
  Future<void> handleGskShare(String roomName, String keyStr) async {
    final keyBytes = base64Decode(keyStr);
    final key = SecretKey(keyBytes);
    _groupKeys[roomName] = key;
    await _secureStorage.write('gsk_$roomName', keyStr);
    Log.d(
      'KeyManager',
      'Received and saved Group Secret Key (GSK) for $roomName',
    );
  }

  /// Sets a group key directly (for TreeKEM integration).
  void setGroupKey(String roomName, SecretKey key) {
    _groupKeys[roomName] = key;
    // Check if we have a pending waiter
    if (_gskCompleters.containsKey(roomName) &&
        !_gskCompleters[roomName]!.isCompleted) {
      _gskCompleters[roomName]!.complete(key);
      _gskCompleters.remove(roomName);
    }
  }

  /// Checks if we have a group key in memory.
  bool hasGroupKey(String roomName) => _groupKeys.containsKey(roomName);

  /// Clears any cached/stored group key for a room.
  Future<void> clearGroupKey(String roomName, {bool clearStored = true}) async {
    _groupKeys.remove(roomName);
    if (_gskCompleters.containsKey(roomName) &&
        !_gskCompleters[roomName]!.isCompleted) {
      _gskCompleters.remove(roomName);
    }
    if (clearStored) {
      await _secureStorage.delete('gsk_$roomName');
    }
  }

  /// Gets or generates the Vault Key for a room.
  Future<SecretKey> getVaultKey(
    String roomName, {
    bool allowGenerateIfMissing = false,
  }) async {
    // 1. Check secure storage
    final keyStr = await _secureStorage.read('key_$roomName');
    if (keyStr != null) {
      // Backfill initialization marker for older installs.
      await _secureStorage.write('vault_key_initialized_$roomName', 'true');
      return SecretKey(base64Decode(keyStr));
    }

    // 2. If alone, generate
    if (getRemoteParticipantCount(roomName) == 0) {
      if (!allowGenerateIfMissing) {
        throw StateError('Vault Key not available for $roomName');
      }
      return _generateAndSaveVaultKey(roomName);
    }

    final initStr = await _secureStorage.read(
      'vault_key_initialized_$roomName',
    );
    final wasInitialized = initStr == 'true';
    final isAuthority = _isVaultKeyAuthority(roomName);

    // Bootstrap: for creating a first vault item, allow the authority to
    // generate a key quickly if no one can provide one.
    if (!wasInitialized && isAuthority && allowGenerateIfMissing) {
      Log.i('KeyManager', 'Vault Key missing for $roomName. Requesting...');
      await _requestVaultKey(roomName);
      try {
        return await _waitForVaultKey(
          roomName,
          timeout: const Duration(seconds: 2),
        );
      } catch (_) {
        Log.i(
          'KeyManager',
          'No peer supplied a Vault Key for $roomName. Generating a new one as authority.',
        );
        final key = await _generateAndSaveVaultKey(roomName);
        await _shareVaultKeyToPeers(
          roomName,
          base64Encode(await key.extractBytes()),
        );
        return key;
      }
    }

    // 3. Request and Wait
    Log.i('KeyManager', 'Vault Key missing for $roomName. Requesting...');
    await _requestVaultKey(roomName);

    try {
      // If the key has never existed, allow a brief window for an existing
      // peer to share it (older versions may not have the init marker).
      final timeout = (!wasInitialized && isAuthority)
          ? const Duration(seconds: 2)
          : const Duration(seconds: 10);

      return await _waitForVaultKey(roomName, timeout: timeout);
    } catch (e) {
      Log.w(
        'KeyManager',
        'Timeout waiting for Vault Key in $roomName: $e. Key must be supplied by another participant before decrypting existing vault items.',
      );

      // Bootstrap generation is only safe if the key has never existed and the
      // caller explicitly permits generation (e.g. creating a new vault item).
      if (!wasInitialized && isAuthority && allowGenerateIfMissing) {
        Log.i(
          'KeyManager',
          'No peer supplied a Vault Key for $roomName. Generating a new one as authority.',
        );
        final key = await _generateAndSaveVaultKey(roomName);
        await _shareVaultKeyToPeers(
          roomName,
          base64Encode(await key.extractBytes()),
        );
        return key;
      }

      if (wasInitialized) {
        Log.w(
          'KeyManager',
          'Vault key appears to have been initialized previously for $roomName but is now missing locally. Refusing to auto-regenerate to avoid data loss.',
        );
      }
      throw StateError('Vault Key not available for $roomName: $e');
    }
  }

  Future<void> _requestVaultKey(String roomName) async {
    Log.d('KeyManager', 'Broadcasting KEY_REQ for $roomName');

    final payload = utf8.encode(jsonEncode({'type': 'KEY_REQ'}));
    final packet = P2PPacket()
      ..type = P2PPacket_PacketType.UNICAST_REQ
      ..requestId = const Uuid().v4()
      ..senderId = getLocalParticipantIdForRoom(roomName)
      ..payload = payload;

    await broadcast(roomName, packet);
  }

  Future<SecretKey> _waitForVaultKey(
    String roomName, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Check storage again (race condition)
    final keyStr = await _secureStorage.read('key_$roomName');
    if (keyStr != null) {
      return SecretKey(base64Decode(keyStr));
    }

    final existing = _vaultKeyCompleters[roomName];
    final completer = (existing != null && !existing.isCompleted)
        ? existing
        : Completer<SecretKey>();
    final createdHere = existing == null || existing.isCompleted;
    if (createdHere) {
      _vaultKeyCompleters[roomName] = completer;
    }

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (createdHere && _vaultKeyCompleters[roomName] == completer) {
            _vaultKeyCompleters.remove(roomName);
          }
          throw TimeoutException(
            'Timed out waiting for Vault Key in $roomName',
          );
        },
      );
    } catch (e) {
      throw StateError('Vault Key not received: $e');
    }
  }

  Future<SecretKey> _generateAndSaveVaultKey(String roomName) async {
    final key = await _encryptionService.generateKey();
    final bytes = await key.extractBytes();
    final keyStr = base64Encode(bytes);
    await _setVaultKey(roomName, keyStr);
    Log.d('KeyManager', 'Generated new Vault Key for $roomName');
    return key;
  }

  /// Handles receiving a shared vault key.
  Future<void> handleVaultKeyShare(String roomName, String keyStr) async {
    final existing = await _secureStorage.read('key_$roomName');
    if (existing == null) {
      await _setVaultKey(roomName, keyStr);
      Log.d('KeyManager', 'Received and saved Vault Key for $roomName');
    }
  }

  /// Shares our vault key with the given peer if it exists locally.
  Future<void> shareVaultKeyIfHeld(String roomName, String targetId) async {
    var keyStr = await _secureStorage.read('key_$roomName');

    // Bootstrap: if we're the authority and the key has never been initialized,
    // try to fetch an existing key first (older versions may not have the init
    // marker), then generate only if no peer supplies one.
    if (keyStr == null && _isVaultKeyAuthority(roomName)) {
      final initStr = await _secureStorage.read(
        'vault_key_initialized_$roomName',
      );
      final wasInitialized = initStr == 'true';
      if (!wasInitialized) {
        await _requestVaultKey(roomName);
        try {
          final key = await _waitForVaultKey(
            roomName,
            timeout: const Duration(seconds: 2),
          );
          keyStr = base64Encode(await key.extractBytes());
        } catch (_) {
          final key = await _generateAndSaveVaultKey(roomName);
          keyStr = base64Encode(await key.extractBytes());
        }
      }
    }

    if (keyStr == null) return;

    Log.d('KeyManager', 'Sharing Vault Key with $targetId in $roomName');
    await _sendVaultKeyToPeer(roomName, targetId, keyStr);
  }
}
