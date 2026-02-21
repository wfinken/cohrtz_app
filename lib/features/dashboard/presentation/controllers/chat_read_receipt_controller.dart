import 'dart:async';

import '../../data/local_dashboard_storage.dart';

class ChatReadReceiptController {
  ChatReadReceiptController(this._storage);

  final LocalDashboardStorage _storage;

  Timer? _debounce;
  ({String groupId, String threadId, int timestampMs})? _pending;
  String? _lastPersistedKey;

  void markVisible({
    required String groupId,
    required String threadId,
    required int timestampMs,
  }) {
    if (groupId.isEmpty || threadId.isEmpty) return;

    _pending = (groupId: groupId, threadId: threadId, timestampMs: timestampMs);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _flush);
  }

  Future<void> _flush() async {
    final pending = _pending;
    if (pending == null) return;

    final writeKey =
        '${pending.groupId}|${pending.threadId}|${pending.timestampMs}';
    if (writeKey == _lastPersistedKey) return;
    _lastPersistedKey = writeKey;

    await _storage.saveReadStatus(
      pending.groupId,
      pending.threadId,
      pending.timestampMs,
    );
  }

  void dispose() {
    _debounce?.cancel();
  }
}
