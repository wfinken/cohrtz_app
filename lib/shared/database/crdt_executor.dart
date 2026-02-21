import 'dart:async';
import 'package:drift/backends.dart';
import 'package:drift/drift.dart';
import 'package:sql_crdt/sql_crdt.dart';

/// A Drift [QueryExecutor] that delegates to a [SqlCrdt] instance.
/// This allows Drift to work on top of the CRDT sync layer.
class CrdtQueryExecutor extends DelegatedDatabase {
  final SqlCrdt crdt;

  CrdtQueryExecutor(this.crdt, {bool logStatements = false})
    : super(_CrdtDelegate(crdt), logStatements: logStatements);

  @override
  bool get isSequential => true;

  /// Merges a changeset into the underlying CRDT database.
  /// After merging, Drift watchers will be notified if [db] is provided.
  Future<void> merge(CrdtChangeset changeset, [GeneratedDatabase? db]) async {
    await crdt.merge(changeset);
    if (db != null) {
      // Notify Drift that tables have changed
      final tableNames = changeset.keys;
      db.markTablesUpdated(
        db.allTables.where((t) => tableNames.contains(t.actualTableName)),
      );
    }
  }
}

class _CrdtDelegate extends DatabaseDelegate {
  final SqlCrdt crdt;
  bool _isOpen = false;

  _CrdtDelegate(this.crdt);

  @override
  late final DbVersionDelegate versionDelegate = _CrdtVersionDelegate(crdt);

  @override
  TransactionDelegate get transactionDelegate => _CrdtTransactionDelegate(crdt);

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> open(QueryExecutorUser user) async {
    _isOpen = true;
  }

  @override
  Future<void> runCustom(String statement, List<Object?> args) async {
    await crdt.execute(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    await crdt.execute(statement, args);
    final result = await crdt.query('SELECT last_insert_rowid() as id');
    return (result.first['id'] as num).toInt();
  }

  @override
  Future<QueryResult> runSelect(String sql, List<Object?> args) async {
    final result = await crdt.query(sql, args);
    return QueryResult.fromRows(result);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    await crdt.execute(statement, args);
    final result = await crdt.query('SELECT changes() as c');
    return (result.first['c'] as num).toInt();
  }
}

class _CrdtVersionDelegate extends DynamicVersionDelegate {
  final SqlCrdt crdt;
  _CrdtVersionDelegate(this.crdt);

  @override
  Future<int> get schemaVersion async {
    final result = await crdt.query('PRAGMA user_version');
    return (result.first['user_version'] as num).toInt();
  }

  @override
  Future<void> setSchemaVersion(int version) async {
    await crdt.execute('PRAGMA user_version = $version');
  }
}

class _CrdtTransactionDelegate extends SupportedTransactionDelegate {
  final SqlCrdt crdt;
  _CrdtTransactionDelegate(this.crdt);

  @override
  FutureOr<void> startTransaction(Future Function(QueryDelegate) run) {
    return crdt.transaction((txn) async {
      return run(_CrdtQueryDelegate(txn));
    });
  }
}

class _CrdtQueryDelegate extends QueryDelegate {
  final CrdtApi api;
  _CrdtQueryDelegate(this.api);

  @override
  Future<void> runCustom(String statement, List<Object?> args) async {
    await api.execute(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    await api.execute(statement, args);
    final result = await api.query('SELECT last_insert_rowid() as id');
    return (result.first['id'] as num).toInt();
  }

  @override
  Future<QueryResult> runSelect(String sql, List<Object?> args) async {
    final result = await api.query(sql, args);
    return QueryResult.fromRows(result);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    await api.execute(statement, args);
    final result = await api.query('SELECT changes() as c');
    return (result.first['c'] as num).toInt();
  }
}
