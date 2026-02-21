import 'dart:async';

enum SyncDiagnosticKind {
  handshake,
  sync,
  data,
  connection,
  security,
  info,
  warning,
  error,
}

enum SyncDiagnosticDirection { inbound, outbound, local }

class SyncDiagnosticEvent {
  final DateTime timestamp;
  final String tag;
  final String message;
  final String roomName;
  final String? peerId;
  final SyncDiagnosticKind kind;
  final SyncDiagnosticDirection direction;
  final int? bytes;
  final bool isSyncCompletion;

  const SyncDiagnosticEvent({
    required this.timestamp,
    required this.tag,
    required this.message,
    required this.roomName,
    required this.kind,
    required this.direction,
    this.peerId,
    this.bytes,
    this.isSyncCompletion = false,
  });
}

class SyncDiagnostics {
  SyncDiagnostics._();

  static final StreamController<SyncDiagnosticEvent> _controller =
      StreamController<SyncDiagnosticEvent>.broadcast();
  static final List<SyncDiagnosticEvent> _recent = <SyncDiagnosticEvent>[];
  static const int _maxRecent = 500;

  static Stream<SyncDiagnosticEvent> get stream => _controller.stream;

  static void emit({
    required String tag,
    required String message,
    required String roomName,
    required SyncDiagnosticKind kind,
    SyncDiagnosticDirection direction = SyncDiagnosticDirection.local,
    String? peerId,
    int? bytes,
    bool isSyncCompletion = false,
  }) {
    if (roomName.isEmpty) return;

    final event = SyncDiagnosticEvent(
      timestamp: DateTime.now(),
      tag: tag,
      message: message,
      roomName: roomName,
      kind: kind,
      direction: direction,
      peerId: peerId,
      bytes: bytes,
      isSyncCompletion: isSyncCompletion,
    );

    _recent.add(event);
    if (_recent.length > _maxRecent) {
      _recent.removeRange(0, _recent.length - _maxRecent);
    }

    _controller.add(event);
  }

  static List<SyncDiagnosticEvent> recentForRoom(
    String roomName, {
    int limit = 100,
  }) {
    if (roomName.isEmpty) return const <SyncDiagnosticEvent>[];

    final filtered = _recent
        .where((e) => e.roomName == roomName)
        .toList(growable: false);
    if (filtered.length <= limit) return filtered;
    return filtered.sublist(filtered.length - limit);
  }
}
