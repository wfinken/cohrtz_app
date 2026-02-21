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
import 'package:fixnum/fixnum.dart' as $fixnum;

import 'p2p_packet.pbenum.dart';

export 'p2p_packet.pbenum.dart';

/// Defines the core packet structure for Cohrtz P2P communication.
class P2PPacket extends $pb.GeneratedMessage {
  factory P2PPacket({
    P2PPacket_PacketType? type,
    $core.String? requestId,
    $core.String? senderId,
    $core.List<$core.int>? signature,
    $core.List<$core.int>? payload,
    $core.int? uncompressedSize,
    $core.int? chunkIndex,
    $core.bool? isLastChunk,
    $core.String? targetId,
    $core.bool? encrypted,
    $core.List<$core.int>? encryptionPublicKey,
    $core.List<$core.int>? senderPublicKey,
    $fixnum.Int64? physicalTime,
    $fixnum.Int64? logicalTime,
  }) {
    final $result = create();
    if (type != null) {
      $result.type = type;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (senderId != null) {
      $result.senderId = senderId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    if (uncompressedSize != null) {
      $result.uncompressedSize = uncompressedSize;
    }
    if (chunkIndex != null) {
      $result.chunkIndex = chunkIndex;
    }
    if (isLastChunk != null) {
      $result.isLastChunk = isLastChunk;
    }
    if (targetId != null) {
      $result.targetId = targetId;
    }
    if (encrypted != null) {
      $result.encrypted = encrypted;
    }
    if (encryptionPublicKey != null) {
      $result.encryptionPublicKey = encryptionPublicKey;
    }
    if (senderPublicKey != null) {
      $result.senderPublicKey = senderPublicKey;
    }
    if (physicalTime != null) {
      $result.physicalTime = physicalTime;
    }
    if (logicalTime != null) {
      $result.logicalTime = logicalTime;
    }
    return $result;
  }
  P2PPacket._() : super();
  factory P2PPacket.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory P2PPacket.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'P2PPacket',
      createEmptyInstance: create)
    ..e<P2PPacket_PacketType>(
        1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE,
        defaultOrMaker: P2PPacket_PacketType.SYNC_REQ,
        valueOf: P2PPacket_PacketType.valueOf,
        enumValues: P2PPacket_PacketType.values)
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'senderId')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..a<$core.int>(
        6, _omitFieldNames ? '' : 'uncompressedSize', $pb.PbFieldType.O3)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'chunkIndex', $pb.PbFieldType.O3)
    ..aOB(8, _omitFieldNames ? '' : 'isLastChunk')
    ..aOS(9, _omitFieldNames ? '' : 'targetId')
    ..aOB(10, _omitFieldNames ? '' : 'encrypted')
    ..a<$core.List<$core.int>>(
        11, _omitFieldNames ? '' : 'encryptionPublicKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        12, _omitFieldNames ? '' : 'senderPublicKey', $pb.PbFieldType.OY)
    ..aInt64(13, _omitFieldNames ? '' : 'physicalTime')
    ..aInt64(14, _omitFieldNames ? '' : 'logicalTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  P2PPacket clone() => P2PPacket()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  P2PPacket copyWith(void Function(P2PPacket) updates) =>
      super.copyWith((message) => updates(message as P2PPacket)) as P2PPacket;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static P2PPacket create() => P2PPacket._();
  P2PPacket createEmptyInstance() => create();
  static $pb.PbList<P2PPacket> createRepeated() => $pb.PbList<P2PPacket>();
  @$core.pragma('dart2js:noInline')
  static P2PPacket getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<P2PPacket>(create);
  static P2PPacket? _defaultInstance;

  @$pb.TagNumber(1)
  P2PPacket_PacketType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(P2PPacket_PacketType v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get payload => $_getN(4);
  @$pb.TagNumber(5)
  set payload($core.List<$core.int> v) {
    $_setBytes(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearPayload() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get uncompressedSize => $_getIZ(5);
  @$pb.TagNumber(6)
  set uncompressedSize($core.int v) {
    $_setSignedInt32(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasUncompressedSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearUncompressedSize() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get chunkIndex => $_getIZ(6);
  @$pb.TagNumber(7)
  set chunkIndex($core.int v) {
    $_setSignedInt32(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasChunkIndex() => $_has(6);
  @$pb.TagNumber(7)
  void clearChunkIndex() => clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isLastChunk => $_getBF(7);
  @$pb.TagNumber(8)
  set isLastChunk($core.bool v) {
    $_setBool(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasIsLastChunk() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsLastChunk() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get targetId => $_getSZ(8);
  @$pb.TagNumber(9)
  set targetId($core.String v) {
    $_setString(8, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasTargetId() => $_has(8);
  @$pb.TagNumber(9)
  void clearTargetId() => clearField(9);

  @$pb.TagNumber(10)
  $core.bool get encrypted => $_getBF(9);
  @$pb.TagNumber(10)
  set encrypted($core.bool v) {
    $_setBool(9, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasEncrypted() => $_has(9);
  @$pb.TagNumber(10)
  void clearEncrypted() => clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get encryptionPublicKey => $_getN(10);
  @$pb.TagNumber(11)
  set encryptionPublicKey($core.List<$core.int> v) {
    $_setBytes(10, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasEncryptionPublicKey() => $_has(10);
  @$pb.TagNumber(11)
  void clearEncryptionPublicKey() => clearField(11);

  @$pb.TagNumber(12)
  $core.List<$core.int> get senderPublicKey => $_getN(11);
  @$pb.TagNumber(12)
  set senderPublicKey($core.List<$core.int> v) {
    $_setBytes(11, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasSenderPublicKey() => $_has(11);
  @$pb.TagNumber(12)
  void clearSenderPublicKey() => clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get physicalTime => $_getI64(12);
  @$pb.TagNumber(13)
  set physicalTime($fixnum.Int64 v) {
    $_setInt64(12, v);
  }

  @$pb.TagNumber(13)
  $core.bool hasPhysicalTime() => $_has(12);
  @$pb.TagNumber(13)
  void clearPhysicalTime() => clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get logicalTime => $_getI64(13);
  @$pb.TagNumber(14)
  set logicalTime($fixnum.Int64 v) {
    $_setInt64(13, v);
  }

  @$pb.TagNumber(14)
  $core.bool hasLogicalTime() => $_has(13);
  @$pb.TagNumber(14)
  void clearLogicalTime() => clearField(14);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
