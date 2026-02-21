import 'dart:convert';
import 'dart:math';

import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/utils/logging_service.dart';

class HybridTimeService {
  HybridTimeService({required String Function() getLocalParticipantId})
    : _getLocalParticipantId = getLocalParticipantId,
      _epochAtStartMs = DateTime.now().toUtc().millisecondsSinceEpoch {
    _stopwatch.start();
  }

  final String Function() _getLocalParticipantId;

  final Stopwatch _stopwatch = Stopwatch();
  final int _epochAtStartMs;

  int _logicalCounter = 0;
  final Map<String, double> _peerOffsetsMs = {};

  double perfNowMs() => _stopwatch.elapsedMicroseconds / 1000.0;

  int monotonicUtcNowMs() => _epochAtStartMs + _stopwatch.elapsedMilliseconds;

  double averagePeerOffsetMs() {
    if (_peerOffsetsMs.isEmpty) return 0;
    final sum = _peerOffsetsMs.values.fold<double>(0, (a, b) => a + b);
    return sum / _peerOffsetsMs.length;
  }

  int getAdjustedTimeUtcMs() =>
      monotonicUtcNowMs() + averagePeerOffsetMs().round();

  DateTime getAdjustedTimeUtc() =>
      DateTime.fromMillisecondsSinceEpoch(getAdjustedTimeUtcMs(), isUtc: true);

  /// Returns the current UTC time corrected by the average offset of all active peers.
  DateTime getAdjustedTime() => getAdjustedTimeUtc();

  DateTime getAdjustedTimeLocal() =>
      DateTime.fromMillisecondsSinceEpoch(getAdjustedTimeUtcMs());

  int nextLogicalTime() {
    _logicalCounter += 1;
    return _logicalCounter;
  }

  int observeRemoteLogicalTime(int remoteLogicalTime) {
    if (remoteLogicalTime <= 0) return _logicalCounter;
    _logicalCounter = max(_logicalCounter, remoteLogicalTime) + 1;
    return _logicalCounter;
  }

  void removePeer(String peerId) {
    _peerOffsetsMs.remove(peerId);
  }

  Map<String, double> peerOffsetsMsSnapshot() =>
      Map.unmodifiable(_peerOffsetsMs);

  void observeIncomingPacket(P2PPacket packet) {
    // Backward compatible: old clients won't set logicalTime.
    final incoming = packet.hasLogicalTime() ? packet.logicalTime.toInt() : 0;
    if (incoming > 0) {
      observeRemoteLogicalTime(incoming);
    }
  }

  void stampOutgoingPacket(P2PPacket packet) {
    // Never mutate an already-signed packet; doing so would invalidate the signature.
    if (packet.signature.isNotEmpty) return;
    if (!packet.hasPhysicalTime() || packet.physicalTime == Int64.ZERO) {
      packet.physicalTime = Int64(getAdjustedTimeUtcMs());
    }
    if (!packet.hasLogicalTime() || packet.logicalTime == Int64.ZERO) {
      packet.logicalTime = Int64(nextLogicalTime());
    }
  }

  P2PPacket buildSyncPing({
    required String peerId,
    String? localParticipantId,
  }) {
    final localId = localParticipantId ?? _getLocalParticipantId();
    final payload = utf8.encode(
      jsonEncode(<String, Object?>{'type': 'SYNC_PING', 't0': perfNowMs()}),
    );

    return P2PPacket()
      ..type = P2PPacket_PacketType.UNICAST_REQ
      ..requestId = const Uuid().v4()
      ..senderId = localId
      ..targetId = peerId
      ..payload = payload;
  }

  P2PPacket buildSyncPong({
    required String targetId,
    required String requestId,
    required double t0,
    required double t1,
    required double t2,
    String? localParticipantId,
  }) {
    final localId = localParticipantId ?? _getLocalParticipantId();
    final payload = utf8.encode(
      jsonEncode(<String, Object?>{
        'type': 'SYNC_PONG',
        't0': t0,
        't1': t1,
        't2': t2,
      }),
    );

    return P2PPacket()
      ..type = P2PPacket_PacketType.UNICAST_REQ
      ..requestId = requestId
      ..senderId = localId
      ..targetId = targetId
      ..payload = payload;
  }

  void handleIncomingSyncPong({
    required String peerId,
    required double t0,
    required double t1,
    required double t2,
  }) {
    final t3 = perfNowMs();

    // Protocol A: Clock Offset Calculation (NTP-style).
    final rtt = (t3 - t0) - (t2 - t1);
    final theta = ((t1 - t0) + (t2 - t3)) / 2.0;

    // Simple smoothing to reduce jitter.
    final existing = _peerOffsetsMs[peerId];
    final smoothed = existing == null
        ? theta
        : (existing * 0.8) + (theta * 0.2);
    _peerOffsetsMs[peerId] = smoothed;

    Log.d(
      'HybridTimeService',
      'Updated offset for $peerId: theta=${theta.toStringAsFixed(2)}ms, rtt=${rtt.toStringAsFixed(2)}ms, avg=${averagePeerOffsetMs().toStringAsFixed(2)}ms',
    );
  }
}
