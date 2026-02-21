import '../../infrastructure/connection_manager.dart';
import 'sync_process.dart';

/// Orchestrates network suspend/restore flows.
///
/// Intended responsibilities:
/// - Suspend all rooms when app goes to background
/// - Restore known connections on resume
class NetworkRecoveryProcess implements SyncProcess {
  final ConnectionManager _connectionManager;

  NetworkRecoveryProcess({required ConnectionManager connectionManager})
    : _connectionManager = connectionManager;

  Future<void> suspend() async {
    await _connectionManager.suspendNetwork();
  }

  Future<void> restore() async {
    await _connectionManager.restoreNetwork();
  }

  @override
  Future<void> execute() async {
    await restore();
  }
}
