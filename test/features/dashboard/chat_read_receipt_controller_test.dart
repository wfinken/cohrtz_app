import 'package:cohortz/features/dashboard/data/local_dashboard_storage.dart';
import 'package:cohortz/features/dashboard/presentation/controllers/chat_read_receipt_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocalDashboardStorage extends LocalDashboardStorage {
  int writes = 0;
  String? lastGroupId;
  String? lastThreadId;
  int? lastTimestamp;

  @override
  Future<void> saveReadStatus(
    String groupId,
    String threadId,
    int timestamp,
  ) async {
    writes += 1;
    lastGroupId = groupId;
    lastThreadId = threadId;
    lastTimestamp = timestamp;
  }
}

void main() {
  test(
    'debounces rapid read receipt writes and keeps latest payload',
    () async {
      final storage = _FakeLocalDashboardStorage();
      final controller = ChatReadReceiptController(storage);

      controller.markVisible(groupId: 'g1', threadId: 't1', timestampMs: 1);
      controller.markVisible(groupId: 'g1', threadId: 't2', timestampMs: 2);
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(storage.writes, 1);
      expect(storage.lastGroupId, 'g1');
      expect(storage.lastThreadId, 't2');
      expect(storage.lastTimestamp, 2);

      controller.dispose();
    },
  );

  test('skips duplicate persisted read receipt payloads', () async {
    final storage = _FakeLocalDashboardStorage();
    final controller = ChatReadReceiptController(storage);

    controller.markVisible(groupId: 'g1', threadId: 't1', timestampMs: 10);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    controller.markVisible(groupId: 'g1', threadId: 't1', timestampMs: 10);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(storage.writes, 1);

    controller.dispose();
  });
}
