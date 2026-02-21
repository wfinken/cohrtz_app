import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/chat/ui/widgets/chat_widget.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/sync/orchestration/sync_service.dart';
import 'package:cohortz/slices/sync/orchestration/processes/network_recovery_process.dart';
import 'package:cohortz/slices/sync/runtime/hybrid_time_service.dart';
import 'package:cohortz/app/di/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/mocks.dart';

// Mocks
// FakeCrdtService is in mocks.dart

class FakeDashboardRepository extends DashboardRepository {
  FakeDashboardRepository()
    : super(
        FakeCrdtService(),
        null,
        HybridTimeService(getLocalParticipantId: () => 'test-user-id'),
      );

  final List<ChatMessage> _messages = [];

  @override
  Stream<List<ChatMessage>> watchMessages({String? threadId}) {
    return Stream.value(_messages);
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    _messages.add(message);
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ChatWidget renders correctly with no messages', (
    WidgetTester tester,
  ) async {
    final generalThread = ChatThread(
      id: ChatThread.generalId,
      kind: ChatThread.channelKind,
      name: 'general',
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            FakeDashboardRepository(),
          ),
          chatThreadsStreamProvider.overrideWith(
            (ref) => Stream.value([generalThread]),
          ),
          threadMessagesStreamProvider.overrideWith(
            (ref, threadId) => Stream.value([]),
          ),
          userProfilesProvider.overrideWith((ref) => Stream.value([])),
          syncServiceProvider.overrideWith(
            () => FakeSyncServiceNotifier(FakeSyncService()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatWidget())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No messages yet.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('ChatWidget renders messages', (WidgetTester tester) async {
    final generalThread = ChatThread(
      id: ChatThread.generalId,
      kind: ChatThread.channelKind,
      name: 'general',
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    final messages = [
      ChatMessage(
        id: '1',
        senderId: 'test-user-id',
        threadId: ChatThread.generalId,
        content: 'Hello World',
        timestamp: DateTime.now(),
      ),
      ChatMessage(
        id: '2',
        senderId: 'other-user',
        threadId: ChatThread.generalId,
        content: 'Hi there',
        timestamp: DateTime.now(),
      ),
    ];

    final profiles = [
      UserProfile(
        id: 'other-user',
        displayName: 'Other User',
        publicKey: 'key',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            FakeDashboardRepository(),
          ),
          chatThreadsStreamProvider.overrideWith(
            (ref) => Stream.value([generalThread]),
          ),
          threadMessagesStreamProvider.overrideWith(
            (ref, threadId) => Stream.value(
              threadId == ChatThread.generalId
                  ? messages
                  : const <ChatMessage>[],
            ),
          ),
          userProfilesProvider.overrideWith((ref) => Stream.value(profiles)),
          syncServiceProvider.overrideWith(
            () => FakeSyncServiceNotifier(FakeSyncService()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatWidget())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Hello World'), findsOneWidget);
    expect(find.textContaining('Hi there'), findsOneWidget);
    expect(find.textContaining('You'), findsOneWidget); // For 'test-user-id'
    expect(find.textContaining('Other User'), findsOneWidget);
  });
}
