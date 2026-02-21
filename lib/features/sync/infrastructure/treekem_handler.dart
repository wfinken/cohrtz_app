import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/logging_service.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/security/security_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/treekem/treekem_service.dart';
import '../../../core/security/treekem/ratchet_tree.dart';
import '../../../core/security/treekem/node.dart';
import 'crdt_service.dart';

/// Manages TreeKEM (Tree Key Encapsulation Mechanism) operations.
///
/// TreeKEM provides efficient group key management with forward secrecy
/// for large groups. This handler encapsulates initialization, state
/// management, and key rotation logic.
class TreeKemHandler {
  final CrdtService _crdtService;
  final EncryptionService _encryptionService;
  final SecureStorageService _secureStorage;
  final SecurityService _securityService;

  /// Active TreeKEM services by room name.
  final Map<String, TreekemService> services = {};
  final Map<String, int> _epochs = {};

  /// Stream controller for group key updates.
  final _keyUpdateController =
      StreamController<(String, SecretKey)>.broadcast();

  /// Stream of group key updates (Room Name, New Key).
  Stream<(String, SecretKey)> get keyUpdates => _keyUpdateController.stream;
  final _epochUpdateController = StreamController<(String, int)>.broadcast();
  Stream<(String, int)> get epochUpdates => _epochUpdateController.stream;

  /// Callback to notify listeners of state changes.
  final VoidCallback? onStateChanged;

  TreeKemHandler({
    required CrdtService crdtService,
    required SecurityService securityService,
    required EncryptionService encryptionService,
    required SecureStorageService secureStorage,
    this.onStateChanged,
  }) : _crdtService = crdtService,
       _securityService = securityService,
       _encryptionService = encryptionService,
       _secureStorage = secureStorage;

  /// Initializes TreeKEM for a room, loading existing state or creating new.
  Future<void> initializeForRoom(String roomName, {bool isHost = false}) async {
    Log.d(
      'TreeKemHandler',
      'Initializing TreeKEM for room $roomName (isHost: $isHost)',
    );

    // 1. Try to load from CRDT and secure storage
    final publicStateJson = await _crdtService.get(
      roomName,
      'treekem_state:$roomName',
    );
    final privateStateJson = await _secureStorage.read(
      'treekem_private_$roomName',
    );

    if (publicStateJson != null && privateStateJson != null) {
      try {
        final tree = RatchetTree.fromJson(jsonDecode(publicStateJson));
        final privateState = jsonDecode(privateStateJson);

        int? myLeafIdx = privateState['myLeafIndex'];

        if (myLeafIdx != null) {
          services[roomName] = await TreekemService.fromFullState(
            tree,
            myLeafIdx,
            privateState,
          );
          _epochs[roomName] = await _loadEpoch(roomName) ?? 1;
          _notifyEpochChanged(roomName);
          Log.i(
            'TreeKemHandler',
            'Loaded existing TreeKEM state for $roomName',
          );
          // Update GSK
          final groupSecret = await services[roomName]!.getGroupSecret();
          _keyUpdateController.add((roomName, SecretKey(groupSecret)));
          return;
        }
      } catch (e) {
        Log.w('TreeKemHandler', 'Failed to load TreeKEM state: $e');
      }
    }

    // 2. Host logic: If we are the creator and no state exists
    if (publicStateJson == null && isHost) {
      Log.i(
        'TreeKemHandler',
        'Creating new TreeKEM state for $roomName (Host)',
      );
      final tree = RatchetTree(1);
      final service = TreekemService(tree, 0);

      // Use deterministic seed from identity for the host's leaf as well
      final seed = await _securityService.getEncryptionSeed(groupId: roomName);
      final seed32 = [...seed, ...seed];
      await service.init(seed32);

      services[roomName] = service;
      _epochs[roomName] = 1;
      await saveState(roomName);
    } else if (publicStateJson == null && !isHost) {
      Log.i(
        'TreeKemHandler',
        'No TreeKEM state found for $roomName. Waiting for Welcome as non-host.',
      );
    }
  }

  /// Saves the TreeKEM state to CRDT and secure storage.
  Future<void> saveState(String roomName) async {
    final service = services[roomName];
    if (service == null) return;

    // Save public state to CRDT
    final publicJson = jsonEncode(service.tree.toJson());
    await _crdtService.put(roomName, 'treekem_state:$roomName', publicJson);

    // Save private state to Secure Storage
    final privateMap = await service.exportPrivateState();
    privateMap['myLeafIndex'] = service.myLeafIndex;
    final privateJson = jsonEncode(privateMap);
    await _secureStorage.write('treekem_private_$roomName', privateJson);
    await _saveEpoch(roomName);

    // Update the group key
    final groupSecret = await service.getGroupSecret();
    _keyUpdateController.add((roomName, SecretKey(groupSecret)));

    Log.d(
      'TreeKemHandler',
      'Saved TreeKEM state and updated GSK for $roomName',
    );
    _notifyEpochChanged(roomName);
    onStateChanged?.call();
  }

  /// Handles an incoming TreeKEM update from a peer.
  Future<void> handleUpdate(
    String roomName,
    String senderId,
    Map<String, dynamic> data,
  ) async {
    final service = services[roomName];
    if (service == null) return;

    Log.d('TreeKemHandler', 'Received TreeKEM_UPDATE from $senderId');

    // Map UpdatePathNode back from JSON
    final list = data['updatePath'] as List;
    final updatePath = list.map((n) {
      final nodeMap = n as Map<String, dynamic>;
      final encryptedMap =
          nodeMap['encryptedPathSecrets'] as Map<String, dynamic>;
      return UpdatePathNode(
        publicKey: base64Decode(nodeMap['publicKey']),
        encryptedPathSecrets: encryptedMap.map(
          (k, v) => MapEntry(int.parse(k), base64Decode(v)),
        ),
      );
    }).toList();

    int senderLeafIdx = data['senderLeafIndex'];
    await service.applyUpdate(senderLeafIdx, updatePath);
    final incomingEpoch = _readEpochValue(data['epoch']);
    final currentEpoch = _epochs[roomName] ?? 1;
    _epochs[roomName] = incomingEpoch != null
        ? (incomingEpoch > currentEpoch ? incomingEpoch : currentEpoch + 1)
        : currentEpoch + 1;
    await saveState(roomName);
  }

  /// Handles an incoming TreeKEM welcome message (joining a group).
  Future<void> handleWelcome(String roomName, Map<String, dynamic> data) async {
    Log.i('TreeKemHandler', 'Received TreeKEM_WELCOME for $roomName');

    // Map WelcomeMessage back from JSON
    final nodesJson = data['nodes'] as List;
    final nodes = nodesJson.map((n) => TreekemNode.fromJson(n)).toList();

    final welcome = WelcomeMessage(
      leafIndex: data['leafIndex'],
      leafCount: data['leafCount'],
      nodes: nodes,
      encryptedPathSecret: base64Decode(data['encryptedPathSecret']),
    );
    final incomingEpoch = _readEpochValue(data['epoch']);

    // Use deterministic seed from identity to ensure consistency with handshake public key
    final seed = await _securityService.getEncryptionSeed(groupId: roomName);
    final seed32 = [...seed, ...seed];

    // Get the actual encryption key pair - this is the key pair whose public key
    // was shared during handshake and used by the host to encrypt the path secret.
    final encryptionKeyPair = await _securityService.getEncryptionKeyPair(
      groupId: roomName,
    );
    final encryptionPubKey = await encryptionKeyPair.extractPublicKey();

    Log.d(
      'TreeKemHandler',
      'Processing WELCOME for $roomName. LeafIndex: ${welcome.leafIndex}',
    );
    Log.d(
      'TreeKemHandler',
      'My Encryption Public Key: ${encryptionPubKey.bytes.take(8).toList()}...',
    );
    Log.d(
      'TreeKemHandler',
      'Encrypted packet length: ${welcome.encryptedPathSecret.length}',
    );

    // 1. Primary Attempt: Use the Identity Key (standard flow)
    try {
      // Diagnostic check: Ensure the key we are using matches what we advertised
      // In a real scenario, we should track which key was sent.
      // For now, if we fail here, we assume it might be the Leaf Key.

      final service = await TreekemService.fromWelcome(
        welcome,
        seed32,
        encryptionKeyPair,
      );
      services[roomName] = service;
      _epochs[roomName] = incomingEpoch ?? 1;
      await saveState(roomName);

      Log.i(
        'TreeKemHandler',
        'Successfully joined TreeKEM group for $roomName (Identity Key)',
      );
      return; // Success
    } catch (e) {
      Log.w('TreeKemHandler', 'Primary decryption (Identity Key) failed: $e');
    }

    // 2. Fallback Attempt: Use the Leaf Key (if we are re-joining/upgrading)
    // If we are already in the group, we might have sent our Leaf Key
    // instead of Identity Key during handshake. The host would have encrypted
    // for that Leaf Key.
    final existingService = services[roomName];
    if (existingService != null) {
      Log.d(
        'TreeKemHandler',
        'Existing service found. Attempting fallback decryption with Leaf Key...',
      );
      try {
        final leafKeyPair = await existingService.getLeafKeyPair();
        if (leafKeyPair != null) {
          final leafPubKey = await leafKeyPair.extractPublicKey();
          Log.d(
            'TreeKemHandler',
            'Trying Leaf Key: ${leafPubKey.bytes.take(8).toList()}...',
          );

          final service = await TreekemService.fromWelcome(
            welcome,
            seed32,
            leafKeyPair,
          );
          services[roomName] = service;
          _epochs[roomName] = incomingEpoch ?? (_epochs[roomName] ?? 1);
          await saveState(roomName);

          Log.i(
            'TreeKemHandler',
            'Successfully rejoined TreeKEM group using Leaf Key for $roomName',
          );
          return; // Success
        } else {
          Log.w('TreeKemHandler', 'Fallback failed: Leaf KeyPair is null');
        }
      } catch (e2) {
        Log.w(
          'TreeKemHandler',
          'Fallback decryption with Leaf Key also failed: $e2',
        );
      }
    } else {
      Log.w('TreeKemHandler', 'No existing service found for fallback.');
    }

    // Failure
    Log.e('TreeKemHandler', 'Fatal: Failed to process WELCOME.', null);
    // Do not rethrow, as this crashes the isolate/unhandled exception handler.
    // We can survive without TreeKEM (using Legacy GSK) until the next handshake/update fixes it.
    Log.w(
      'TreeKemHandler',
      'Continuing without active TreeKEM service for now.',
    );
  }

  /// Gets the TreeKEM service for a room, or null if not active.
  TreekemService? getService(String roomName) => services[roomName];

  int getEpoch(String roomName) => _epochs[roomName] ?? 0;

  /// Checks if a member with given public key exists in the tree.
  bool memberExists(String roomName, List<int> publicKey) {
    final service = services[roomName];
    if (service == null) return true; // Assume exists if no TreeKEM

    for (int i = 0; i < service.tree.leafCount; i++) {
      final node = service.tree.nodes[2 * i];
      if (node.publicKey != null &&
          listEquals(node.publicKey!.bytes, publicKey)) {
        return true;
      }
    }
    return false;
  }

  /// Adds a new member to the tree and returns welcome/update data.
  Future<TreeKemOnboardResult> addMember(
    String roomName,
    List<int> memberPublicKey,
  ) async {
    final service = services[roomName];
    if (service == null) {
      throw StateError('TreeKEM not active for $roomName');
    }

    int newLeafIdx = service.tree.leafCount;
    service.tree.expand(newLeafIdx + 1);

    // 1. Insert the new member into the tree (Locally)
    // This is crucial: We must know about them to encrypt for them (if we were to send direct)
    // and they must be in the tree structure before we rotate the key so they are included in the new epoch.
    final newMemberNode = TreekemNode(
      publicKey: SimplePublicKey(memberPublicKey, type: KeyPairType.x25519),
    );
    service.tree.nodes[2 * newLeafIdx] = newMemberNode;

    // 2. Rotate group key for forward secrecy (Create Update)
    // We do this BEFORE creating the welcome message so that the Welcome message
    // contains the NEW root secrets that include the new member.
    final seed = await _encryptionService.generateSalt();
    final seed32 = [...seed, ...seed];
    final updatePath = await service.createUpdate(seed32);
    final epoch = _incrementEpoch(roomName);

    // 3. Create welcome message (Encrypt current state for new member)
    // Now that the tree is updated and keys rotated, we welcome them.
    final welcome = await service.welcomeNewMember(newLeafIdx, memberPublicKey);

    await saveState(roomName);

    return TreeKemOnboardResult(
      welcome: welcome,
      myLeafIndex: service.myLeafIndex,
      updatePath: updatePath,
      epoch: epoch,
    );
  }

  /// Rotates local TreeKEM secrets and advances epoch for the room.
  Future<TreeKemUpdateResult> rotateEpoch(String roomName) async {
    final service = services[roomName];
    if (service == null) {
      throw StateError('TreeKEM not active for $roomName');
    }

    final seed = await _encryptionService.generateSalt();
    final seed32 = [...seed, ...seed];
    final updatePath = await service.createUpdate(seed32);
    final epoch = _incrementEpoch(roomName);
    await saveState(roomName);

    return TreeKemUpdateResult(
      senderLeafIndex: service.myLeafIndex,
      updatePath: updatePath,
      epoch: epoch,
    );
  }

  /// Clears state for a room (on disconnect/forget).
  void clearRoom(String roomName) {
    services.remove(roomName);
    _epochs.remove(roomName);
    _notifyEpochChanged(roomName);
  }

  Future<void> dispose() async {
    await _keyUpdateController.close();
    await _epochUpdateController.close();
  }

  int _incrementEpoch(String roomName) {
    final next = (_epochs[roomName] ?? 0) + 1;
    _epochs[roomName] = next;
    return next;
  }

  int? _readEpochValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<int?> _loadEpoch(String roomName) async {
    final value = await _secureStorage.read('treekem_epoch_$roomName');
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> _saveEpoch(String roomName) async {
    final epoch = _epochs[roomName];
    if (epoch == null) return;
    await _secureStorage.write('treekem_epoch_$roomName', '$epoch');
  }

  void _notifyEpochChanged(String roomName) {
    _epochUpdateController.add((roomName, _epochs[roomName] ?? 0));
  }
}

/// Result of adding a new member to TreeKEM.
class TreeKemOnboardResult {
  final WelcomeMessage welcome;
  final int myLeafIndex;
  final List<UpdatePathNode> updatePath;
  final int epoch;

  TreeKemOnboardResult({
    required this.welcome,
    required this.myLeafIndex,
    required this.updatePath,
    required this.epoch,
  });
}

class TreeKemUpdateResult {
  final int senderLeafIndex;
  final List<UpdatePathNode> updatePath;
  final int epoch;

  TreeKemUpdateResult({
    required this.senderLeafIndex,
    required this.updatePath,
    required this.epoch,
  });
}
