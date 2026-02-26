import 'package:drift/drift.dart';

@DataClassName('PollEntity')
class Polls extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
