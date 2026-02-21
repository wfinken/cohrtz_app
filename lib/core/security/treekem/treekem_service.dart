import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'ratchet_tree.dart';
import 'crypto_utils.dart';
import 'node.dart';

/// A node in the UpdatePath sent during a Commit.
class UpdatePathNode {
  final List<int> publicKey;
  final Map<int, List<int>>
  encryptedPathSecrets; // resolution_node_index -> ciphertext

  UpdatePathNode({required this.publicKey, required this.encryptedPathSecrets});

  Map<String, dynamic> toJson() => {
    'publicKey': base64Encode(publicKey),
    'encryptedPathSecrets': encryptedPathSecrets.map(
      (k, v) => MapEntry(k.toString(), base64Encode(v)),
    ),
  };
}

/// A Welcome message used to invite a new member to the group.
class WelcomeMessage {
  final int leafIndex;
  final int leafCount;
  final List<TreekemNode> nodes;
  final List<int> encryptedPathSecret;

  WelcomeMessage({
    required this.leafIndex,
    required this.leafCount,
    required this.nodes,
    required this.encryptedPathSecret,
  });

  Map<String, dynamic> toJson() => {
    'leafIndex': leafIndex,
    'leafCount': leafCount,
    'nodes': nodes.map((n) {
      if (n.isBlank) return {'isBlank': true};
      return {'publicKey': base64Encode(n.publicKey!.bytes)};
    }).toList(),
    'encryptedPathSecret': base64Encode(encryptedPathSecret),
  };
}

/// Orchestrates TreeKEM operations: update, join, leave.
class TreekemService {
  final RatchetTree tree;
  final int myLeafIndex;

  /// Private keys for nodes on our direct path.
  final Map<int, SimpleKeyPair> _nodeKeyPairs = {};

  /// Path secrets for nodes on our direct path.
  final Map<int, List<int>> _pathSecrets = {};

  TreekemService(this.tree, this.myLeafIndex);

  /// Returns the key pair for our leaf node.
  Future<SimpleKeyPair?> getLeafKeyPair() async {
    return _nodeKeyPairs[2 * myLeafIndex];
  }

  /// Initialize the service with our own leaf secret.
  Future<void> init(List<int> leafSecret) async {
    int leafIdx = 2 * myLeafIndex;
    _pathSecrets[leafIdx] = leafSecret;
    List<int> nodeSecret = await TreekemCrypto.deriveSecret(leafSecret, "node");
    _nodeKeyPairs[leafIdx] = await TreekemCrypto.deriveKeyPair(nodeSecret);

    SimplePublicKey pubKey = await _nodeKeyPairs[leafIdx]!.extractPublicKey();
    tree.nodes[leafIdx] = TreekemNode(publicKey: pubKey);
  }

  /// Performs an 'Update' operation to rotate the group key.
  /// Generates a new leaf secret and derives a new path of secrets to the root.
  /// Returns the UpdatePath to be shared with the group.
  Future<List<UpdatePathNode>> createUpdate(List<int> leafSecret) async {
    List<UpdatePathNode> updatePath = [];
    int n = tree.leafCount;

    List<int> currentPathSecret = leafSecret;
    List<int> directPath = RatchetTree.directPath(myLeafIndex, n);

    for (int i = 0; i < directPath.length; i++) {
      int curr = directPath[i];

      List<int> nodeSecret = await TreekemCrypto.deriveSecret(
        currentPathSecret,
        "node",
      );
      SimpleKeyPair keyPair = await TreekemCrypto.deriveKeyPair(nodeSecret);
      _nodeKeyPairs[curr] = keyPair;
      _pathSecrets[curr] = currentPathSecret;

      SimplePublicKey pubKey = await keyPair.extractPublicKey();
      // Update the local tree state
      tree.nodes[curr] = TreekemNode(publicKey: pubKey);

      Map<int, List<int>> encryptedPathSecrets = {};

      if (curr != RatchetTree.rootIndex(n)) {
        // Derive next path secret for the parent
        List<int> nextPathSecret = await TreekemCrypto.deriveSecret(
          currentPathSecret,
          "path",
        );

        int sib = RatchetTree.getSibling(curr, n);
        List<int> resolution = tree.resolution(sib);

        // Encrypt the NEXT path secret for everyone in the sibling's resolution
        for (int resIdx in resolution) {
          TreekemNode resNode = tree.nodes[resIdx];
          if (resNode.publicKey != null) {
            List<int> encrypted = await TreekemCrypto.hpkeSeal(
              resNode.publicKey!.bytes,
              nextPathSecret,
            );
            encryptedPathSecrets[resIdx] = encrypted;
          }
        }
        currentPathSecret = nextPathSecret;
      }

      updatePath.add(
        UpdatePathNode(
          publicKey: pubKey.bytes,
          encryptedPathSecrets: encryptedPathSecrets,
        ),
      );
    }

    return updatePath;
  }

  /// Processes an UpdatePath from another member.
  /// [senderLeafIndex] is the leaf index of the member who sent the update.
  /// [updatePath] is the list of UpdatePathNodes.
  Future<void> applyUpdate(
    int senderLeafIndex,
    List<UpdatePathNode> updatePath,
  ) async {
    int n = tree.leafCount;
    List<int> senderDirectPath = RatchetTree.directPath(senderLeafIndex, n);
    List<int> myDirectPath = RatchetTree.directPath(myLeafIndex, n);

    for (int i = 0; i < updatePath.length; i++) {
      int nodeIdx = senderDirectPath[i];
      tree.nodes[nodeIdx] = TreekemNode(
        publicKey: SimplePublicKey(
          updatePath[i].publicKey,
          type: KeyPairType.x25519,
        ),
      );
    }

    int commonNodeIdx = -1;
    int senderPathIdx = -1;

    for (int i = 0; i < senderDirectPath.length; i++) {
      if (myDirectPath.contains(senderDirectPath[i])) {
        commonNodeIdx = senderDirectPath[i];
        senderPathIdx = i;
        break;
      }
    }

    if (commonNodeIdx == -1) {
      // No common node? Should only happen if we are not in the group.
      return;
    }

    if (senderPathIdx <= 0) {
      // If we are interpreting our own update, or something is wrong
      debugPrint(
        '[TreekemService] senderPathIdx is <= 0 ($senderPathIdx). Skipping decryption.',
      );
      return;
    }

    int childOfCommonOnSenderPath = senderDirectPath[senderPathIdx - 1];
    int myAncestorAtThatLevel = RatchetTree.getSibling(
      childOfCommonOnSenderPath,
      n,
    );

    // The resolution of myAncestorAtThatLevel should contain one of our nodes that we have a private key for.
    List<int> res = tree.resolution(myAncestorAtThatLevel);
    int? overlapIdx;
    for (int idx in res) {
      if (_nodeKeyPairs.containsKey(idx)) {
        overlapIdx = idx;
        break;
      }
    }

    if (overlapIdx == null) {
      // We can't decrypt any part of this update path.
      return;
    }

    List<int>? sealedSecret =
        updatePath[senderPathIdx - 1].encryptedPathSecrets[overlapIdx];
    if (sealedSecret == null) return;

    List<int> decryptedPathSecret = await TreekemCrypto.hpkeOpen(
      _nodeKeyPairs[overlapIdx]!,
      sealedSecret,
    );

    List<int> currentPathSecret = decryptedPathSecret;
    for (int i = senderPathIdx; i < senderDirectPath.length; i++) {
      int curr = senderDirectPath[i];
      _pathSecrets[curr] = currentPathSecret;

      List<int> nodeSecret = await TreekemCrypto.deriveSecret(
        currentPathSecret,
        "node",
      );
      _nodeKeyPairs[curr] = await TreekemCrypto.deriveKeyPair(nodeSecret);

      if (curr != RatchetTree.rootIndex(n)) {
        currentPathSecret = await TreekemCrypto.deriveSecret(
          currentPathSecret,
          "path",
        );
      }
    }
  }

  /// Returns the current group secret (derived from the root path secret).
  Future<List<int>> getGroupSecret() async {
    int rootIdx = RatchetTree.rootIndex(tree.leafCount);
    List<int>? rootPathSecret = _pathSecrets[rootIdx];
    if (rootPathSecret == null) {
      throw StateError("We don't know the root secret!");
    }

    return await TreekemCrypto.deriveSecret(rootPathSecret, "group");
  }

  /// Generates a Welcome message for a new member.
  /// [newMemberLeafIndex] is the index the new member will occupy.
  /// [newMemberPublicKey] is the public key from the new member's KeyPackage.
  Future<WelcomeMessage> welcomeNewMember(
    int newMemberLeafIndex,
    List<int> newMemberPublicKey,
  ) async {
    int n = tree.leafCount;
    int rootIdx = RatchetTree.rootIndex(n);

    // Ensure we have derived secrets up to the root
    await _ensurePathSecrets();

    // We send the current root path secret encrypted for the new member
    List<int>? rootPathSecret = _pathSecrets[rootIdx];
    if (rootPathSecret == null) {
      throw StateError(
        "Could not derive root path secret for welcome message. "
        "Root index: $rootIdx, Tree leaf count: $n",
      );
    }

    debugPrint(
      '[TreekemService] Encrypting WELCOME for pubKey: ${newMemberPublicKey.take(8).toList()}...',
    );
    debugPrint(
      '[TreekemService] Root path secret length: ${rootPathSecret.length}',
    );

    List<int> encrypted = await TreekemCrypto.hpkeSeal(
      newMemberPublicKey,
      rootPathSecret,
    );

    return WelcomeMessage(
      leafIndex: newMemberLeafIndex,
      leafCount: n,
      nodes: List.from(tree.nodes),
      encryptedPathSecret: encrypted,
    );
  }

  /// Ensures that path secrets and node key pairs are derived for all nodes
  /// on our direct path up to the current root.
  Future<void> _ensurePathSecrets() async {
    int n = tree.leafCount;
    List<int> path = RatchetTree.directPath(myLeafIndex, n);

    for (int i = 0; i < path.length; i++) {
      int curr = path[i];

      // If we don't have the path secret for this node, we must derive it from the child
      if (!_pathSecrets.containsKey(curr)) {
        if (i == 0) {
          // This should not happen if init() was called
          debugPrint(
            "[TreekemService] Leaf path secret missing for leaf $myLeafIndex at index $curr",
          );
          continue;
        }

        int prev = path[i - 1];
        if (!_pathSecrets.containsKey(prev)) {
          debugPrint(
            "[TreekemService] Cannot derive path secret for $curr: previous node $prev missing secret.",
          );
          continue;
        }

        List<int> prevPathSecret = _pathSecrets[prev]!;

        List<int> nextPathSecret = await TreekemCrypto.deriveSecret(
          prevPathSecret,
          "path",
        );
        _pathSecrets[curr] = nextPathSecret;
      }

      // Also ensure we have the node key pair
      if (!_nodeKeyPairs.containsKey(curr) && _pathSecrets.containsKey(curr)) {
        List<int> nodeSecret = await TreekemCrypto.deriveSecret(
          _pathSecrets[curr]!,
          "node",
        );
        _nodeKeyPairs[curr] = await TreekemCrypto.deriveKeyPair(nodeSecret);

        // Update the public key in the tree if it's blank or mismatch?
        // Usually, we trust our own derivation.
        SimplePublicKey pubKey = await _nodeKeyPairs[curr]!.extractPublicKey();
        tree.nodes[curr] = TreekemNode(publicKey: pubKey);
      }
    }
  }

  /// Initializes a TreekemService from a Welcome message.
  /// [encryptionKeyPair] is the recipient's X25519 key pair (from handshake identity).
  /// This must match the public key that the host encrypted the path secret for.
  static Future<TreekemService> fromWelcome(
    WelcomeMessage welcome,
    List<int> leafSecret,
    SimpleKeyPair encryptionKeyPair,
  ) async {
    int n = welcome.leafCount;
    final tree = RatchetTree(n);
    for (int i = 0; i < welcome.nodes.length; i++) {
      tree.nodes[i] = welcome.nodes[i];
    }

    final service = TreekemService(tree, welcome.leafIndex);
    await service.init(leafSecret);

    // Decrypt using the actual encryption key pair (matches the public key from handshake)
    // The host encrypted using our handshake encryption public key.
    List<int> decryptedRootPathSecret = await TreekemCrypto.hpkeOpen(
      encryptionKeyPair,
      welcome.encryptedPathSecret,
    );

    int rootIdx = RatchetTree.rootIndex(n);
    service._pathSecrets[rootIdx] = decryptedRootPathSecret;
    List<int> nodeSecret = await TreekemCrypto.deriveSecret(
      decryptedRootPathSecret,
      "node",
    );
    service._nodeKeyPairs[rootIdx] = await TreekemCrypto.deriveKeyPair(
      nodeSecret,
    );

    return service;
  }

  /// Removes a member from the tree by blanking their leaf and all nodes on their direct path.
  void removeMember(int leafIndex) {
    int n = tree.leafCount;
    List<int> path = RatchetTree.directPath(leafIndex, n);
    for (int nodeIdx in path) {
      tree.nodes[nodeIdx] = TreekemNode.blank();
      _nodeKeyPairs.remove(nodeIdx);
      _pathSecrets.remove(nodeIdx);
    }
  }

  /// Exports the private state (key pairs and path secrets) for secure storage.
  Future<Map<String, dynamic>> exportPrivateState() async {
    Map<String, String> keyPairs = {};
    for (var entry in _nodeKeyPairs.entries) {
      final keyData = await entry.value.extract();
      keyPairs[entry.key.toString()] = base64Encode(keyData.bytes);
    }

    Map<String, String> pathSecrets = {};
    for (var entry in _pathSecrets.entries) {
      pathSecrets[entry.key.toString()] = base64Encode(entry.value);
    }

    return {'nodeKeyPairs': keyPairs, 'pathSecrets': pathSecrets};
  }

  /// Reconstructs a TreekemService from public tree state and private state.
  static Future<TreekemService> fromFullState(
    RatchetTree tree,
    int myLeafIndex,
    Map<String, dynamic> privateState,
  ) async {
    final service = TreekemService(tree, myLeafIndex);

    final keyPairsJson = privateState['nodeKeyPairs'] as Map<String, dynamic>;
    for (var entry in keyPairsJson.entries) {
      final idx = int.parse(entry.key);
      final seed = base64Decode(entry.value as String);
      service._nodeKeyPairs[idx] = await TreekemCrypto.deriveKeyPair(seed);
    }

    final pathSecretsJson = privateState['pathSecrets'] as Map<String, dynamic>;
    for (var entry in pathSecretsJson.entries) {
      final idx = int.parse(entry.key);
      service._pathSecrets[idx] = base64Decode(entry.value as String);
    }

    return service;
  }
}
