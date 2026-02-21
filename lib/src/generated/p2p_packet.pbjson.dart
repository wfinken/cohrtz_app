//
//  Generated code. Do not modify.
//  source: p2p_packet.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use p2PPacketDescriptor instead')
const P2PPacket$json = {
  '1': 'P2PPacket',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.P2PPacket.PacketType',
      '10': 'type'
    },
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'sender_id', '3': 3, '4': 1, '5': 9, '10': 'senderId'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'payload', '3': 5, '4': 1, '5': 12, '10': 'payload'},
    {
      '1': 'uncompressed_size',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'uncompressedSize'
    },
    {'1': 'chunk_index', '3': 7, '4': 1, '5': 5, '10': 'chunkIndex'},
    {'1': 'is_last_chunk', '3': 8, '4': 1, '5': 8, '10': 'isLastChunk'},
    {'1': 'target_id', '3': 9, '4': 1, '5': 9, '10': 'targetId'},
    {'1': 'encrypted', '3': 10, '4': 1, '5': 8, '10': 'encrypted'},
    {
      '1': 'encryption_public_key',
      '3': 11,
      '4': 1,
      '5': 12,
      '10': 'encryptionPublicKey'
    },
    {
      '1': 'sender_public_key',
      '3': 12,
      '4': 1,
      '5': 12,
      '10': 'senderPublicKey'
    },
  ],
  '4': [P2PPacket_PacketType$json],
};

@$core.Deprecated('Use p2PPacketDescriptor instead')
const P2PPacket_PacketType$json = {
  '1': 'PacketType',
  '2': [
    {'1': 'SYNC_REQ', '2': 0},
    {'1': 'SYNC_CLAIM', '2': 1},
    {'1': 'DATA_CHUNK', '2': 2},
    {'1': 'HANDSHAKE', '2': 3},
    {'1': 'CONSISTENCY_CHECK', '2': 4},
    {'1': 'INVITE_REQ', '2': 5},
    {'1': 'INVITE_ACK', '2': 6},
    {'1': 'INVITE_NACK', '2': 7},
    {'1': 'UNICAST_REQ', '2': 8},
    {'1': 'UNICAST_ACK', '2': 9},
  ],
};

/// Descriptor for `P2PPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List p2PPacketDescriptor = $convert.base64Decode(
    'CglQMlBQYWNrZXQSKQoEdHlwZRgBIAEoDjIVLlAyUFBhY2tldC5QYWNrZXRUeXBlUgR0eXBlEh'
    '0KCnJlcXVlc3RfaWQYAiABKAlSCXJlcXVlc3RJZBIbCglzZW5kZXJfaWQYAyABKAlSCHNlbmRl'
    'cklkEhwKCXNpZ25hdHVyZRgEIAEoDFIJc2lnbmF0dXJlEhgKB3BheWxvYWQYBSABKAxSB3BheW'
    'xvYWQSKwoRdW5jb21wcmVzc2VkX3NpemUYBiABKAVSEHVuY29tcHJlc3NlZFNpemUSHwoLY2h1'
    'bmtfaW5kZXgYByABKAVSCmNodW5rSW5kZXgSIgoNaXNfbGFzdF9jaHVuaxgIIAEoCFILaXNMYX'
    'N0Q2h1bmsSGwoJdGFyZ2V0X2lkGAkgASgJUgh0YXJnZXRJZBIcCgllbmNyeXB0ZWQYCiABKAhS'
    'CWVuY3J5cHRlZBIyChVlbmNyeXB0aW9uX3B1YmxpY19rZXkYCyABKAxSE2VuY3J5cHRpb25QdW'
    'JsaWNLZXkSKgoRc2VuZGVyX3B1YmxpY19rZXkYDCABKAxSD3NlbmRlclB1YmxpY0tleSKzAQoK'
    'UGFja2V0VHlwZRIMCghTWU5DX1JFURAAEg4KClNZTkNfQ0xBSU0QARIOCgpEQVRBX0NIVU5LEA'
    'ISDQoJSEFORFNIQUtFEAMSFQoRQ09OU0lTVEVOQ1lfQ0hFQ0sQBBIOCgpJTlZJVEVfUkVREAUS'
    'DgoKSU5WSVRFX0FDSxAGEg8KC0lOVklURV9OQUNLEAcSDwoLVU5JQ0FTVF9SRVEQCBIPCgtVTk'
    'lDQVNUX0FDSxAJ');
