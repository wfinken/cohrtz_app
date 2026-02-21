import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/core/security/treekem/ratchet_tree.dart';
import 'package:cohortz/core/security/treekem/treekem_service.dart';
import 'package:cohortz/core/security/treekem/node.dart';
import 'package:cohortz/core/security/treekem/crypto_utils.dart';

void main() {
  group('TreekemService', () {
    test('Two-user sync', () async {
      int leafCount = 2;

      // 1. Initial seeds for leaves
      final seed0 = List<int>.generate(32, (i) => i);
      final seed1 = List<int>.generate(32, (i) => i + 100);

      final service0 = TreekemService(RatchetTree(leafCount), 0);
      final service1 = TreekemService(RatchetTree(leafCount), 1);

      // Initialize both with their initial leaf secrets
      await service0.init(seed0);
      await service1.init(seed1);

      // Share public keys to build initial tree (simulation of Welcome/Join)
      final pub0 = service0.tree.nodes[0].publicKey!;
      final pub1 = service1.tree.nodes[2].publicKey!;

      service0.tree.nodes[2] = TreekemNode(publicKey: pub1);
      service1.tree.nodes[0] = TreekemNode(publicKey: pub0);

      // 2. User 0 rotates their key
      final newLeafSecret0 = List<int>.generate(32, (i) => i + 50);
      final updatePath = await service0.createUpdate(newLeafSecret0);

      // 3. User 1 applies User 0's update
      await service1.applyUpdate(0, updatePath);

      // 4. Verify group secrets match
      final secret0 = await service0.getGroupSecret();
      final secret1 = await service1.getGroupSecret();

      expect(secret0, secret1);

      // 5. Verification: User 1 rotates key
      final newLeafSecret1 = List<int>.generate(32, (i) => i + 75);
      final updatePath1 = await service1.createUpdate(newLeafSecret1);

      await service0.applyUpdate(1, updatePath1);

      final finalSecret0 = await service0.getGroupSecret();
      final finalSecret1 = await service1.getGroupSecret();

      expect(finalSecret0, finalSecret1);
      expect(finalSecret0, isNot(secret0)); // Key should have rotated
    });

    test('Welcome/Join sync', () async {
      int leafCount = 2;
      final seed0 = List<int>.generate(32, (i) => i);
      final seed1 = List<int>.generate(32, (i) => i + 100);

      final service0 = TreekemService(RatchetTree(leafCount), 0);
      await service0.init(seed0);

      // User 0 rotates to establish the tree's root secret
      await service0.createUpdate(List<int>.generate(32, (i) => i + 10));

      // User 1's "KeyPackage" public key - must be derived the same way TreekemService does it
      final nodeSecret1 = await TreekemCrypto.deriveSecret(seed1, "node");
      final kp1 = await TreekemCrypto.deriveKeyPair(nodeSecret1);
      final pub1 = await kp1.extractPublicKey();

      // User 0 welcomes User 1
      final welcome = await service0.welcomeNewMember(1, pub1.bytes);

      // User 1 joins using the Welcome message
      final service1 = await TreekemService.fromWelcome(welcome, seed1, kp1);

      final secret0 = await service0.getGroupSecret();
      final secret1 = await service1.getGroupSecret();

      expect(secret0, secret1);
    });
  });
}
