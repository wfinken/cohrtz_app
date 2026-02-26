import 'package:drift/drift.dart';

@DataClassName('GroupSettingsEntity')
class GroupSettingsTable extends Table {
  @override
  String get tableName => 'group_settings';
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
