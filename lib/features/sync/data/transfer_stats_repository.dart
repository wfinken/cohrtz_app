import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/sync_diagnostics.dart';

class TransferStatsRepository {
  static const _sentBytesKey = 'transfer_stats_sent_bytes';
  static const _receivedBytesKey = 'transfer_stats_received_bytes';

  final SharedPreferences _prefs;
  final StreamController<({int sent, int received})> _statsController =
      StreamController.broadcast();
  StreamSubscription? _diagnosticSubscription;

  TransferStatsRepository(this._prefs) {
    _init();
  }

  int get totalSentBytes => _prefs.getInt(_sentBytesKey) ?? 0;
  int get totalReceivedBytes => _prefs.getInt(_receivedBytesKey) ?? 0;

  Stream<({int sent, int received})> get statsStream => _statsController.stream;

  void _init() {
    _diagnosticSubscription = SyncDiagnostics.stream.listen((event) {
      if (event.bytes != null && event.bytes! > 0) {
        if (event.direction == SyncDiagnosticDirection.outbound) {
          _incrementSent(event.bytes!);
        } else if (event.direction == SyncDiagnosticDirection.inbound) {
          _incrementReceived(event.bytes!);
        }
      }
    });

    // Emit initial values
    _emitStats();
  }

  Future<void> _incrementSent(int bytes) async {
    final current = totalSentBytes;
    await _prefs.setInt(_sentBytesKey, current + bytes);
    _emitStats();
  }

  Future<void> _incrementReceived(int bytes) async {
    final current = totalReceivedBytes;
    await _prefs.setInt(_receivedBytesKey, current + bytes);
    _emitStats();
  }

  void _emitStats() {
    _statsController.add((sent: totalSentBytes, received: totalReceivedBytes));
  }

  void dispose() {
    _diagnosticSubscription?.cancel();
    _statsController.close();
  }
}

final transferStatsRepositoryProvider = Provider<TransferStatsRepository>((
  ref,
) {
  throw UnimplementedError('Provider was not initialized with override');
});
