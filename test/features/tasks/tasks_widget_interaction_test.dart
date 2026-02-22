import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/sync/orchestration/processes/network_recovery_process.dart';
import 'package:cohortz/slices/sync/orchestration/sync_service.dart';
import 'package:cohortz/slices/sync/runtime/hybrid_time_service.dart';
import 'package:cohortz/slices/tasks/ui/dialogs/task_details_dialog.dart';
import 'package:cohortz/slices/tasks/ui/widgets/tasks_widget.dart';

import '../../helpers/mocks.dart';

class FakeDashboardRepository extends DashboardRepository {
  FakeDashboardRepository()
    : super(
        FakeCrdtService(),
        'room-1',
        HybridTimeService(getLocalParticipantId: () => 'test-user-id'),
      );

  TaskItem? lastSavedTask;
  String? deletedTaskId;

  @override
  Future<void> saveTask(TaskItem task) async {
    lastSavedTask = task;
  }

  @override
  Future<void> deleteTask(String id) async {
    deletedTaskId = id;
  }
}

class FakeSyncService extends SyncService {
  FakeSyncService()
    : super(
        connectionManager: FakeConnectionManager(),
        groupManager: FakeGroupManager(),
        keyManager: FakeKeyManager(),
        inviteHandler: FakeInviteHandler(),
        networkRecoveryProcess: NetworkRecoveryProcess(
          connectionManager: FakeConnectionManager(),
        ),
      );

  @override
  String? get identity => 'test-user-id';
}

class FakeSyncServiceNotifier extends SyncServiceNotifier {
  final FakeSyncService _fakeService;

  FakeSyncServiceNotifier(this._fakeService);

  @override
  SyncService build() => _fakeService;
}

GroupSettings _groupSettings() {
  return GroupSettings(
    id: 'group:1',
    name: 'Home',
    createdAt: DateTime(2026, 2, 1),
    dataRoomName: 'room-1',
    groupType: GroupType.team,
  );
}

TaskItem _task({bool isCompleted = false, String creatorId = 'creator-1'}) {
  return TaskItem(
    id: 'task:1',
    title: 'Weekly sweep',
    assignedTo: 'Alex',
    assigneeId: 'user-2',
    priority: TaskPriority.high,
    creatorId: creatorId,
    isCompleted: isCompleted,
    dueDate: DateTime(2026, 2, 24),
    dueTime: '14:5',
    repeat: 'Weekly',
    reminder: '30 min before',
    notes: 'Check the entry and kitchen floors',
    subtasks: [
      TaskSubtask(title: 'Entryway'),
      TaskSubtask(title: 'Kitchen', isCompleted: true),
    ],
  );
}

Widget _buildWidget({
  required FakeDashboardRepository repository,
  required List<TaskItem> tasks,
  required int permissions,
}) {
  return ProviderScope(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(repository),
      tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
      groupSettingsProvider.overrideWith(
        (ref) => Stream.value(_groupSettings()),
      ),
      logicalGroupsProvider.overrideWith(
        (ref) => const [
          LogicalGroup(
            id: AclGroupIds.everyone,
            name: 'Everyone',
            isSystem: true,
          ),
        ],
      ),
      currentUserPermissionsProvider.overrideWith((ref) async => permissions),
      syncServiceProvider.overrideWith(
        () => FakeSyncServiceNotifier(FakeSyncService()),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: TasksWidget())),
  );
}

void main() {
  testWidgets('checkbox toggles completion without opening dialog', (
    tester,
  ) async {
    final repository = FakeDashboardRepository();
    final task = _task();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        tasks: [task],
        permissions: PermissionFlags.editTasks,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task_checkbox_task:1')));
    await tester.pumpAndSettle();

    expect(repository.lastSavedTask, isNotNull);
    expect(repository.lastSavedTask!.isCompleted, isTrue);
    expect(repository.lastSavedTask!.completedBy, 'test-user-id');
    expect(find.byType(TaskDetailsDialog), findsNothing);
  });

  testWidgets('tile tap opens details dialog without toggling completion', (
    tester,
  ) async {
    final repository = FakeDashboardRepository();
    final task = _task();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        tasks: [task],
        permissions: PermissionFlags.editTasks,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task_tile_task:1')));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailsDialog), findsOneWidget);
    expect(repository.lastSavedTask, isNull);
    expect(find.text('SUBTASKS'), findsOneWidget);
    expect(find.text('Weekly sweep'), findsWidgets);
  });

  testWidgets('subtask toggle in dialog persists changes', (tester) async {
    final repository = FakeDashboardRepository();
    final task = _task();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        tasks: [task],
        permissions: PermissionFlags.editTasks,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task_tile_task:1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('task_dialog_subtask_task:1_0')),
    );
    await tester.tap(
      find.byKey(const ValueKey('task_dialog_subtask_task:1_0')),
    );
    await tester.pumpAndSettle();

    expect(repository.lastSavedTask, isNotNull);
    expect(repository.lastSavedTask!.subtasks[0].isCompleted, isTrue);
    expect(repository.lastSavedTask!.subtasks[1].isCompleted, isTrue);
  });

  testWidgets('checkbox tap without completion permissions does nothing', (
    tester,
  ) async {
    final repository = FakeDashboardRepository();
    final task = _task();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        tasks: [task],
        permissions: PermissionFlags.none,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task_checkbox_task:1')));
    await tester.pumpAndSettle();

    expect(repository.lastSavedTask, isNull);
    expect(find.byType(TaskDetailsDialog), findsNothing);
  });

  testWidgets('subtask tap without permissions does not persist changes', (
    tester,
  ) async {
    final repository = FakeDashboardRepository();
    final task = _task();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        tasks: [task],
        permissions: PermissionFlags.none,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task_tile_task:1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('task_dialog_subtask_task:1_0')),
    );
    await tester.tap(
      find.byKey(const ValueKey('task_dialog_subtask_task:1_0')),
    );
    await tester.pumpAndSettle();

    expect(repository.lastSavedTask, isNull);
    expect(
      find.text('You do not have permission to edit subtasks.'),
      findsOneWidget,
    );
  });

  testWidgets('visibility icon opens visibility selector, not details dialog', (
    tester,
  ) async {
    final repository = FakeDashboardRepository();
    final task = _task();

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        tasks: [task],
        permissions: PermissionFlags.editTasks,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task_visibility_task:1')));
    await tester.pumpAndSettle();

    expect(find.text('Visibility Groups'), findsOneWidget);
    expect(find.byType(TaskDetailsDialog), findsNothing);
  });

  testWidgets('delete icon deletes task without opening details dialog', (
    tester,
  ) async {
    final repository = FakeDashboardRepository();
    final task = _task(isCompleted: true, creatorId: 'test-user-id');

    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        tasks: [task],
        permissions: PermissionFlags.none,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task_delete_task:1')));
    await tester.pumpAndSettle();

    expect(repository.deletedTaskId, 'task:1');
    expect(find.byType(TaskDetailsDialog), findsNothing);
  });
}
