import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'secure_kv_backend.dart';

class NativeSqlBlobBackend implements SecureKvBackend {
  final Future<String> Function() _baseDirectoryProvider;
  final String _databaseName;

  Database? _db;
  Future<void>? _initializationFuture;

  NativeSqlBlobBackend({
    Future<String> Function()? baseDirectoryProvider,
    String? databaseName,
  }) : _baseDirectoryProvider = baseDirectoryProvider ?? _defaultBaseDirectory,
       _databaseName = databaseName ?? _defaultDatabaseName();

  @override
  Future<void> initialize() async {
    if (_db != null) return;
    if (_initializationFuture != null) return _initializationFuture!;
    final future = _initializeInternal();
    _initializationFuture = future;
    try {
      await future;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    if (_db != null) return;
    final baseDir = await _baseDirectoryProvider();
    final path = p.join(baseDir, _databaseName);
    final db = sqlite3.open(path);
    db.execute('''
      CREATE TABLE IF NOT EXISTS secure_blobs (
        key TEXT PRIMARY KEY,
        value BLOB NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    _db = db;
  }

  @override
  Future<Uint8List?> read(String key) async {
    await initialize();
    final rows = _db!.select(
      'SELECT value FROM secure_blobs WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'];
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    throw StateError(
      'Unexpected blob type for key "$key": ${value.runtimeType}',
    );
  }

  @override
  Future<void> write(String key, Uint8List value) async {
    await initialize();
    _db!.execute(
      '''
      INSERT INTO secure_blobs (key, value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET
        value = excluded.value,
        updated_at = excluded.updated_at
      ''',
      [key, value, DateTime.now().millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> delete(String key) async {
    await initialize();
    _db!.execute('DELETE FROM secure_blobs WHERE key = ?', [key]);
  }

  @override
  Future<bool> containsKey(String key) async {
    await initialize();
    final rows = _db!.select(
      'SELECT 1 as found FROM secure_blobs WHERE key = ? LIMIT 1',
      [key],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> deleteAll() async {
    await initialize();
    _db!.execute('DELETE FROM secure_blobs');
  }

  static Future<String> _defaultBaseDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }

  static String _defaultDatabaseName() {
    if (_isFlutterTest()) {
      return 'cohrtz_secure_test_${Isolate.current.hashCode}.db';
    }
    return 'cohrtz_secure.db';
  }

  static bool _isFlutterTest() {
    return const bool.fromEnvironment('FLUTTER_TEST') ||
        Platform.environment.containsKey('FLUTTER_TEST');
  }
}
