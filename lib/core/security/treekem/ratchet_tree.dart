import 'node.dart';

/// Navigation logic for the TreeKEM Ratchet Tree.
/// Based on RFC 9420 Section 4.1.
class RatchetTree {
  List<TreekemNode> nodes;
  int leafCount;

  RatchetTree(this.leafCount)
    : nodes = List.generate(nodeCount(leafCount), (i) => TreekemNode.blank());

  Map<String, dynamic> toJson() => {
    'leafCount': leafCount,
    'nodes': nodes.map((n) => n.toJson()).toList(),
  };

  factory RatchetTree.fromJson(Map<String, dynamic> json) {
    int leafCount = json['leafCount'] as int;
    final tree = RatchetTree(leafCount);
    final nodesJson = json['nodes'] as List<dynamic>;
    int required = nodeCount(leafCount);
    if (tree.nodes.length < required) {
      tree.nodes.addAll(
        List.generate(required - tree.nodes.length, (_) => TreekemNode.blank()),
      );
    }
    for (int i = 0; i < nodesJson.length && i < tree.nodes.length; i++) {
      tree.nodes[i] = TreekemNode.fromJson(
        nodesJson[i] as Map<String, dynamic>,
      );
    }
    return tree;
  }

  /// Returns the number of nodes in a tree with [n] leaves.
  /// This must be large enough for bitwise navigation (next power of 2).
  static int nodeCount(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    int width = 1;
    while (width < n) {
      width <<= 1;
    }
    return 2 * width - 1;
  }

  /// Returns the level of the node at index [x].
  /// Leaves are at level 0.
  static int level(int x) {
    if (x % 2 == 0) return 0;
    int k = 0;
    while (((x >> k) & 0x01) == 1) {
      k++;
    }
    return k;
  }

  /// Returns the index of the left child of node [x].
  static int left(int x) {
    int k = level(x);
    if (k == 0) throw ArgumentError('Leaf nodes have no children');
    return x ^ (0x01 << (k - 1));
  }

  /// Returns the index of the right child of node [x].
  static int right(int x) {
    int k = level(x);
    if (k == 0) throw ArgumentError('Leaf nodes have no children');
    return x ^ (0x03 << (k - 1));
  }

  /// Returns the index of the parent of node [x].
  /// Note: Returns [x] if it's the root of the tree with [n] leaves.
  static int parent(int x, int n) {
    int r = rootIndex(n);
    if (x == r) return x;

    int k = level(x);
    int b = (x >> (k + 1)) & 0x01;
    return (b == 0) ? (x + (1 << k)) : (x - (1 << k));
  }

  /// Returns the index of the sibling of node [x].
  static int sibling(int x, int n) {
    if (x == rootIndex(n)) return x;
    return getSibling(x, n);
  }

  static int getSibling(int x, int n) {
    int p = parent(x, n);
    if (p == x) return x;
    int l = left(p);
    return (l == x) ? right(p) : l;
  }

  /// Returns the index of the root of a tree with [n] leaves.
  static int rootIndex(int n) {
    if (n <= 1) return 0;
    int width = 1;
    while (width < n) {
      width <<= 1;
    }
    return width - 1;
  }

  /// Returns the direct path from leaf [i] to the root.
  static List<int> directPath(int i, int n) {
    List<int> path = [];
    int x = 2 * i; // Leaf index
    int r = rootIndex(n);
    while (x != r) {
      path.add(x);
      x = parent(x, n);
    }
    path.add(r);
    return path;
  }

  /// Returns the copath of leaf [i].
  /// The copath is the set of siblings of the nodes on the direct path.
  static List<int> copath(int i, int n) {
    List<int> path = [];
    int x = 2 * i;
    int r = rootIndex(n);
    while (x != r) {
      path.add(getSibling(x, n));
      x = parent(x, n);
    }
    return path;
  }

  /// Returns the resolution of a node.
  /// For a leaf, it's just the leaf index.
  /// For an internal node, it's the resolution of its children.
  /// This is used to encrypt path secrets for siblings.
  List<int> resolution(int x) {
    if (nodes[x].isOccupied) {
      return [x];
    }
    if (level(x) == 0) return [];

    return [...resolution(left(x)), ...resolution(right(x))];
  }

  /// Expands the tree to a new leaf count.
  void expand(int newLeafCount) {
    if (newLeafCount <= leafCount) return;
    int newNodeCount = nodeCount(newLeafCount);
    if (newNodeCount > nodes.length) {
      int toAdd = newNodeCount - nodes.length;
      nodes.addAll(List.generate(toAdd, (i) => TreekemNode.blank()));
    }
    leafCount = newLeafCount;
  }
}
