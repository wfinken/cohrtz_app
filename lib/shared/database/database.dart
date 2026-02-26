import 'package:drift/drift.dart';
import 'package:cohortz/slices/calendar/state/db/calendar_events_table.dart';
import 'package:cohortz/slices/chat/state/db/chat_messages_table.dart';
import 'package:cohortz/slices/chat/state/db/chat_threads_table.dart';
import 'package:cohortz/slices/dashboard_shell/state/db/avatar_blobs_table.dart';
import 'package:cohortz/slices/dashboard_shell/state/db/dashboard_widgets_table.dart';
import 'package:cohortz/slices/dashboard_shell/state/db/group_settings_table.dart';
import 'package:cohortz/slices/dashboard_shell/state/db/user_profiles_table.dart';
import 'package:cohortz/slices/notes/state/db/notes_table.dart';
import 'package:cohortz/slices/permissions_feature/state/db/logical_groups_table.dart';
import 'package:cohortz/slices/permissions_feature/state/db/members_table.dart';
import 'package:cohortz/slices/permissions_feature/state/db/roles_table.dart';
import 'package:cohortz/slices/polls/state/db/polls_table.dart';
import 'package:cohortz/slices/tasks/state/db/tasks_table.dart';
import 'package:cohortz/slices/vault/state/db/vault_items_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Notes,
    Tasks,
    CalendarEvents,
    VaultItems,
    ChatMessages,
    ChatThreads,
    UserProfiles,
    AvatarBlobs,
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
