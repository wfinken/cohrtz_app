import 'package:drift/drift.dart';

@DataClassName('AvatarBlobEntity')
class AvatarBlobs extends Table {
  @override
  String get tableName => 'avatar_blob_cache';

  TextColumn get id => text()();
  BlobColumn get data => blob()();

  @override
  Set<Column> get primaryKey => {id};
}
