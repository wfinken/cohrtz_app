import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sql_crdt/sql_crdt.dart';

class Sqlite3ExecutorApi extends DatabaseApi {
  final Database _db;

  Sqlite3ExecutorApi(this._db);

  @override
  Future<void> execute(String sql, [List<Object?>? args]) async {
    _db.execute(sql, args ?? const []);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? args,
  ]) async {
    final resultSet = _db.select(sql, args ?? const []);
    return resultSet.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<void> transaction(
    Future<void> Function(ReadWriteApi api) actions,
  ) async {
    _db.execute('BEGIN');
    try {
      final api = Sqlite3ExecutorApi(_db);
      await actions(api);
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> close() async => _db.dispose();

  @override
  Future<void> executeBatch(
    FutureOr<void> Function(WriteApi api) actions,
  ) async {
    _db.execute('BEGIN');
    try {
      final api = Sqlite3ExecutorApi(_db);
      await actions(api);
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

class EncryptedSqliteCrdt extends SqlCrdt {
  final Database _db;
  void Function(Iterable<String> affectedTables, Hlc hlc)?
  onDatasetChangedCallback;

  EncryptedSqliteCrdt._(this._db) : super(Sqlite3ExecutorApi(_db));

  @override
  Future<void> onDatasetChanged(
    Iterable<String> affectedTables,
    Hlc hlc,
  ) async {
    await super.onDatasetChanged(affectedTables, hlc);
    onDatasetChangedCallback?.call(affectedTables, hlc);
  }

  static Future<EncryptedSqliteCrdt> open(
    String path, {
    String? password,
    bool singleInstance = true,
    int? version,
    FutureOr<void> Function(CrdtTableExecutor db, int version)? onCreate,
    FutureOr<void> Function(CrdtTableExecutor db, int from, int to)? onUpgrade,
  }) => _open(
    path,
    false,
    singleInstance,
    version,
    onCreate,
    onUpgrade,
    password,
  );

  static Future<EncryptedSqliteCrdt> _open(
    String? path,
    bool inMemory,
    bool singleInstance,
    int? version,
    FutureOr<void> Function(CrdtTableExecutor crdt, int version)? onCreate,
    FutureOr<void> Function(CrdtTableExecutor crdt, int from, int to)?
    onUpgrade,
    String? password,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported for EncryptedSqliteCrdt yet.',
      );
    }

    final db = inMemory ? sqlite3.openInMemory() : sqlite3.open(path!);

    if (password != null) {
      db.execute("PRAGMA key = '$password'");
    }

    final crdt = EncryptedSqliteCrdt._(db);

    await crdt.init();

    if (version != null) {
      final result = db.select('PRAGMA user_version');
      final currentVersion = result.first['user_version'] as int;

      final executor = CrdtTableExecutor(Sqlite3ExecutorApi(db));

      if (currentVersion == 0) {
        if (onCreate != null) {
          await onCreate(executor, version);
        }
      } else if (currentVersion < version) {
        if (onUpgrade != null) {
          await onUpgrade(executor, currentVersion, version);
        }
      }

      if (currentVersion != version) {
        db.execute('PRAGMA user_version = $version');
      }
    }

    return crdt;
  }

  Future<void> close() async => _db.dispose();

  @override
  Future<Iterable<String>> getTables() async {
    final result = _db.select('''
      SELECT name FROM sqlite_schema
      WHERE type ='table' AND name NOT LIKE 'sqlite_%'
    ''');
    return result.map((e) => e['name'] as String);
  }

  @override
  Future<Iterable<String>> getTableKeys(String table) async {
    final result = _db.select(
      '''
         SELECT name FROM pragma_table_info(?1)
         WHERE pk > 0
       ''',
      [table],
    );
    return result.map((e) => e['name'] as String);
  }
}
