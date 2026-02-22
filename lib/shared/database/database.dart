import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('NoteEntity')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskEntity')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CalendarEventEntity')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('VaultItemEntity')
class VaultItems extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChatMessageEntity')
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChatThreadEntity')
class ChatThreads extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UserProfileEntity')
class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MemberEntity')
class Members extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoleEntity')
class Roles extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

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

@DataClassName('DashboardWidgetEntity')
class DashboardWidgets extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LogicalGroupEntity')
class LogicalGroups extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PollEntity')
class Polls extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get isDeleted =>
      integer().named('is_deleted').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Notes,
    Tasks,
    CalendarEvents,
    VaultItems,
    ChatMessages,
    ChatThreads,
    UserProfiles,
    Members,
    Roles,
    GroupSettingsTable,
    DashboardWidgets,
    LogicalGroups,
    Polls,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
