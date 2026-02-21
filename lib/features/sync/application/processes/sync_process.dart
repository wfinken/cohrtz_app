/// Base interface for sync-related processes.
///
/// Processes orchestrate multiple managers/services to perform
/// a higher-level workflow (invite join, initial sync, rekey, etc.).
abstract class SyncProcess {
  Future<void> execute();
}
