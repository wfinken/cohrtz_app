import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/shared/security/treekem/ratchet_tree.dart';

void main() {
  group('RatchetTree Indexing', () {
    test('level', () {
      expect(RatchetTree.level(0), 0);
      expect(RatchetTree.level(2), 0);
      expect(RatchetTree.level(4), 0);
      expect(RatchetTree.level(6), 0);
      expect(RatchetTree.level(1), 1);
      expect(RatchetTree.level(5), 1);
      expect(RatchetTree.level(3), 2);
    });

    test('left and right', () {
      expect(RatchetTree.left(1), 0);
      expect(RatchetTree.right(1), 2);
      expect(RatchetTree.left(3), 1);
      expect(RatchetTree.right(3), 5);
      expect(RatchetTree.left(5), 4);
      expect(RatchetTree.right(5), 6);
    });

    test('parent', () {
      // Tree with 4 leaves, root is 3
      int n = 4;
      expect(RatchetTree.parent(0, n), 1);
      expect(RatchetTree.parent(2, n), 1);
      expect(RatchetTree.parent(1, n), 3);
      expect(RatchetTree.parent(5, n), 3);
      expect(RatchetTree.parent(4, n), 5);
      expect(RatchetTree.parent(6, n), 5);
      expect(RatchetTree.parent(3, n), 3); // Root
    });

    test('getSibling', () {
      int n = 4;
      expect(RatchetTree.getSibling(0, n), 2);
      expect(RatchetTree.getSibling(2, n), 0);
      expect(RatchetTree.getSibling(4, n), 6);
      expect(RatchetTree.getSibling(6, n), 4);
      expect(RatchetTree.getSibling(1, n), 5);
      expect(RatchetTree.getSibling(5, n), 1);
    });

    test('rootIndex', () {
      expect(RatchetTree.rootIndex(1), 0);
      expect(RatchetTree.rootIndex(2), 1);
      expect(RatchetTree.rootIndex(3), 3);
      expect(RatchetTree.rootIndex(4), 3);
      expect(RatchetTree.rootIndex(5), 7);
      expect(RatchetTree.rootIndex(8), 7);
    });

    test('directPath', () {
      int n = 4;
      // Leaf 0 (index 0) path: 0 -> 1 -> 3
      expect(RatchetTree.directPath(0, n), [0, 1, 3]);
      // Leaf 1 (index 2) path: 2 -> 1 -> 3
      expect(RatchetTree.directPath(1, n), [2, 1, 3]);
      // Leaf 2 (index 4) path: 4 -> 5 -> 3
      expect(RatchetTree.directPath(2, n), [4, 5, 3]);
    });

    test('copath', () {
      int n = 4;
      // Leaf 0 (index 0) copath: sibling(0)=2, sibling(1)=5
      expect(RatchetTree.copath(0, n), [2, 5]);
      // Leaf 1 (index 2) copath: sibling(2)=0, sibling(1)=5
      expect(RatchetTree.copath(1, n), [0, 5]);
      // Leaf 2 (index 4) copath: sibling(4)=6, sibling(5)=1
      expect(RatchetTree.copath(2, n), [6, 1]);
    });
  });
}
