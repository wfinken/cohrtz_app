// This is a generated file - do not edit.
//
// Generated from p2p_packet.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'p2p_packet.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

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
    final result = create();
    if (type != null) result.type = type;
    if (requestId != null) result.requestId = requestId;
    if (senderId != null) result.senderId = senderId;
    if (signature != null) result.signature = signature;
    if (payload != null) result.payload = payload;
    if (uncompressedSize != null) result.uncompressedSize = uncompressedSize;
    if (chunkIndex != null) result.chunkIndex = chunkIndex;
    if (isLastChunk != null) result.isLastChunk = isLastChunk;
    if (targetId != null) result.targetId = targetId;
    if (encrypted != null) result.encrypted = encrypted;
    if (encryptionPublicKey != null)
      result.encryptionPublicKey = encryptionPublicKey;
    if (senderPublicKey != null) result.senderPublicKey = senderPublicKey;
    if (physicalTime != null) result.physicalTime = physicalTime;
    if (logicalTime != null) result.logicalTime = logicalTime;
    return result;
  }

  P2PPacket._();

  factory P2PPacket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory P2PPacket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'P2PPacket',
      createEmptyInstance: create)
    ..aE<P2PPacket_PacketType>(1, _omitFieldNames ? '' : 'type',
        enumValues: P2PPacket_PacketType.values)
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'senderId')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aI(6, _omitFieldNames ? '' : 'uncompressedSize')
    ..aI(7, _omitFieldNames ? '' : 'chunkIndex')
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

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  P2PPacket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  P2PPacket copyWith(void Function(P2PPacket) updates) =>
      super.copyWith((message) => updates(message as P2PPacket)) as P2PPacket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static P2PPacket create() => P2PPacket._();
  @$core.override
  P2PPacket createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static P2PPacket getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<P2PPacket>(create);
  static P2PPacket? _defaultInstance;

  @$pb.TagNumber(1)
  P2PPacket_PacketType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(P2PPacket_PacketType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get payload => $_getN(4);
  @$pb.TagNumber(5)
  set payload($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearPayload() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get uncompressedSize => $_getIZ(5);
  @$pb.TagNumber(6)
  set uncompressedSize($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUncompressedSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearUncompressedSize() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get chunkIndex => $_getIZ(6);
  @$pb.TagNumber(7)
  set chunkIndex($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasChunkIndex() => $_has(6);
  @$pb.TagNumber(7)
  void clearChunkIndex() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isLastChunk => $_getBF(7);
  @$pb.TagNumber(8)
  set isLastChunk($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsLastChunk() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsLastChunk() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get targetId => $_getSZ(8);
  @$pb.TagNumber(9)
  set targetId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTargetId() => $_has(8);
  @$pb.TagNumber(9)
  void clearTargetId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get encrypted => $_getBF(9);
  @$pb.TagNumber(10)
  set encrypted($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEncrypted() => $_has(9);
  @$pb.TagNumber(10)
  void clearEncrypted() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get encryptionPublicKey => $_getN(10);
  @$pb.TagNumber(11)
  set encryptionPublicKey($core.List<$core.int> value) => $_setBytes(10, value);
  @$pb.TagNumber(11)
  $core.bool hasEncryptionPublicKey() => $_has(10);
  @$pb.TagNumber(11)
  void clearEncryptionPublicKey() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.List<$core.int> get senderPublicKey => $_getN(11);
  @$pb.TagNumber(12)
  set senderPublicKey($core.List<$core.int> value) => $_setBytes(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSenderPublicKey() => $_has(11);
  @$pb.TagNumber(12)
  void clearSenderPublicKey() => $_clearField(12);

  /// Hybrid P2P Time Synchronization System
  /// physical_time: sender wall-clock time (UTC ms) adjusted by sender's peer offset(s)
  /// logical_time: Lamport logical clock
  @$pb.TagNumber(13)
  $fixnum.Int64 get physicalTime => $_getI64(12);
  @$pb.TagNumber(13)
  set physicalTime($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasPhysicalTime() => $_has(12);
  @$pb.TagNumber(13)
  void clearPhysicalTime() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get logicalTime => $_getI64(13);
  @$pb.TagNumber(14)
  set logicalTime($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasLogicalTime() => $_has(13);
  @$pb.TagNumber(14)
  void clearLogicalTime() => $_clearField(14);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
