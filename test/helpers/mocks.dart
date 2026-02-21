import 'package:cohortz/slices/sync/runtime/connection_manager.dart';
import 'package:cohortz/slices/sync/runtime/group_manager.dart';
import 'package:cohortz/slices/sync/runtime/key_manager.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';
import 'package:cohortz/slices/sync/runtime/treekem_handler.dart';
import 'package:cohortz/slices/sync/orchestration/invite_handler.dart';
import 'package:cohortz/shared/security/security_service.dart';
import 'package:cohortz/shared/security/secure_storage_service.dart';
import 'package:cohortz/shared/security/encryption_service.dart';

// --- Base Service Fakes ---

class FakeCrdtService extends CrdtService {
  @override
  Future<void> initialize(
    String nodeId,
    String dbName, {
    String? basePath,
    String? databaseName,
  }) async {}
}

class FakeSecurityService extends SecurityService {
  @override
  Future<void> initialize() async {}
}

class FakeEncryptionService extends EncryptionService {}

class FakeSecureStorageService implements SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<bool> containsKey(String key) async => false;
  @override
  Future<void> deleteAll() async {}
  @override
  bool get isSecure => false;
}

// --- Manager Fakes ---

class FakeGroupManager extends GroupManager {
  FakeGroupManager() : super(secureStorage: FakeSecureStorageService());

  @override
  List<Map<String, String?>> get knownGroups => [];
}

class FakeConnectionManager extends ConnectionManager {
  FakeConnectionManager()
    : super(
        crdtService: FakeCrdtService(),
        securityService: FakeSecurityService(),
        secureStorage: FakeSecureStorageService(),
        groupManager: FakeGroupManager(),
        nodeId: 'test-node',
        onDataReceived: (room, event) {},
        onParticipantConnected: (room, event) {},
        onParticipantDisconnected: (room, event) {},
        onRoomConnectionStateChanged: (manager, room) {},
        onLocalDataChanged: (room, data) {},
        onInitializeSync: (room, isHost) async {},
        onCleanupSync: (room) {},
      );

  @override
  void startJanitors() {
    // Disable background timers in tests.
  }
}

class FakeTreeKemHandler extends TreeKemHandler {
  FakeTreeKemHandler()
    : super(
        crdtService: FakeCrdtService(),
        securityService: FakeSecurityService(),
        encryptionService: FakeEncryptionService(),
        secureStorage: FakeSecureStorageService(),
      );
}

class FakeKeyManager extends KeyManager {
  FakeKeyManager()
    : super(
        encryptionService: FakeEncryptionService(),
        secureStorage: FakeSecureStorageService(),
        treeKemHandler: FakeTreeKemHandler(),
        getLocalParticipantIdForRoom: (_) => 'test-id',
        broadcast: (room, packet) async {},
        sendSecure: (room, target, packet) async {},
        getRemoteParticipantCount: (room) => 0,
        isHost: (room) => false,
      );
}

class FakeInviteHandler extends InviteHandler {
  FakeInviteHandler()
    : super(
        crdtService: FakeCrdtService(),
        getLocalParticipantIdForRoom: (_) => 'test-id',
        broadcast: (room, packet) async {},
        getConnectedRoomNames: () => <String>{},
      );
}
