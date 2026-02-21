import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// A node in the TreeKEM ratchet tree.
class TreekemNode {
  final SimplePublicKey? publicKey;
  final bool isBlank;

  TreekemNode({this.publicKey, this.isBlank = false});

  factory TreekemNode.blank() => TreekemNode(isBlank: true);

  Map<String, dynamic> toJson() => {
    'publicKey': publicKey != null ? base64Encode(publicKey!.bytes) : null,
    'isBlank': isBlank,
  };

  factory TreekemNode.fromJson(Map<String, dynamic> json) {
    return TreekemNode(
      publicKey: json['publicKey'] != null
          ? SimplePublicKey(
              base64Decode(json['publicKey'] as String),
              type: KeyPairType.x25519,
            )
          : null,
      isBlank: json['isBlank'] as bool? ?? false,
    );
  }

  bool get isOccupied => !isBlank;

  @override
  String toString() =>
      isBlank ? 'Node(blank)' : 'Node(pub: ${publicKey?.bytes.take(4)}...)';
}
