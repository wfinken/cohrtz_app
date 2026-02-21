//
//  Generated code. Do not modify.
//  source: p2p_packet.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class P2PPacket_PacketType extends $pb.ProtobufEnum {
  static const P2PPacket_PacketType SYNC_REQ =
      P2PPacket_PacketType._(0, _omitEnumNames ? '' : 'SYNC_REQ');
  static const P2PPacket_PacketType SYNC_CLAIM =
      P2PPacket_PacketType._(1, _omitEnumNames ? '' : 'SYNC_CLAIM');
  static const P2PPacket_PacketType DATA_CHUNK =
      P2PPacket_PacketType._(2, _omitEnumNames ? '' : 'DATA_CHUNK');
  static const P2PPacket_PacketType HANDSHAKE =
      P2PPacket_PacketType._(3, _omitEnumNames ? '' : 'HANDSHAKE');
  static const P2PPacket_PacketType CONSISTENCY_CHECK =
      P2PPacket_PacketType._(4, _omitEnumNames ? '' : 'CONSISTENCY_CHECK');
  static const P2PPacket_PacketType INVITE_REQ =
      P2PPacket_PacketType._(5, _omitEnumNames ? '' : 'INVITE_REQ');
  static const P2PPacket_PacketType INVITE_ACK =
      P2PPacket_PacketType._(6, _omitEnumNames ? '' : 'INVITE_ACK');
  static const P2PPacket_PacketType INVITE_NACK =
      P2PPacket_PacketType._(7, _omitEnumNames ? '' : 'INVITE_NACK');
  static const P2PPacket_PacketType UNICAST_REQ =
      P2PPacket_PacketType._(8, _omitEnumNames ? '' : 'UNICAST_REQ');
  static const P2PPacket_PacketType UNICAST_ACK =
      P2PPacket_PacketType._(9, _omitEnumNames ? '' : 'UNICAST_ACK');

  static const $core.List<P2PPacket_PacketType> values = <P2PPacket_PacketType>[
    SYNC_REQ,
    SYNC_CLAIM,
    DATA_CHUNK,
    HANDSHAKE,
    CONSISTENCY_CHECK,
    INVITE_REQ,
    INVITE_ACK,
    INVITE_NACK,
    UNICAST_REQ,
    UNICAST_ACK,
  ];

  static final $core.Map<$core.int, P2PPacket_PacketType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static P2PPacket_PacketType? valueOf($core.int value) => _byValue[value];

  const P2PPacket_PacketType._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
