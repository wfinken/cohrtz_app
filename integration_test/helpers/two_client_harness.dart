import 'dart:convert';
import 'dart:async';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/shared/config/app_config.dart';
import 'package:cohortz/shared/security/encryption_service.dart';
import 'package:cohortz/shared/security/identity_service.dart';
import 'package:cohortz/shared/security/secure_storage_service.dart';
import 'package:cohortz/shared/security/security_service.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/notes/state/note_repository.dart';
import 'package:cohortz/slices/permissions_feature/state/member_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/member_repository.dart';
import 'package:cohortz/slices/permissions_feature/state/role_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/role_repository.dart';
import 'package:cohortz/slices/sync/orchestration/sync_service.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'e2e_env_config.dart';
import 'eventual_assert.dart';

class E2eClientContext {
  E2eClientContext({
    required this.label,
    required this.identity,
    required this.room,
    required this.dataRoomName,
    required this.container,
    required this.sync,
  });

  final String label;
  final String identity;
  final String room;
  final String dataRoomName;
  final ProviderContainer container;
  final SyncService sync;

  DashboardRepository get dashboard =>
      container.read(dashboardRepositoryProvider);
  NoteRepository get notes => container.read(noteRepositoryProvider);
  MemberRepository get members => container.read(memberRepositoryProvider);
  RoleRepository get roles => container.read(roleRepositoryProvider);
}

class TwoClientHarness {
  TwoClientHarness._({
    required this.clientA,
    required this.clientB,
    required this.config,
  });

  final E2eClientContext clientA;
  final E2eClientContext clientB;
  final E2eEnvConfig config;

  static Future<TwoClientHarness> start(E2eEnvConfig config) async {
    SharedPreferences.setMockInitialValues({});

    final clientA = await _createClient(
      label: 'clientA',
      identity: config.identityA,
      room: config.room,
      dataRoomName: '${config.room}__client_a',
    );
    final clientB = await _createClient(
      label: 'clientB',
      identity: config.identityB,
      room: config.room,
      dataRoomName: '${config.room}__client_b',
    );

    try {
      final tokenResults = await Future.wait<String>([
        _fetchToken(config.room, config.identityA),
        _fetchToken(config.room, config.identityB),
      ]);

      await clientA.sync.connect(
        tokenResults[0],
        config.room,
        identity: config.identityA,
        friendlyName: config.room,
        dataRoomName: clientA.dataRoomName,
      );
      await clientB.sync.connect(
        tokenResults[1],
        config.room,
        identity: config.identityB,
        friendlyName: config.room,
        dataRoomName: clientB.dataRoomName,
      );

      await expectEventually(
        description: 'both clients should connect and discover each other',
        condition: () async {
          return clientA.sync.isConnected &&
              clientB.sync.isConnected &&
              clientA.sync.getRemoteParticipantCount(config.room) >= 1 &&
              clientB.sync.getRemoteParticipantCount(config.room) >= 1;
        },
      );

      return TwoClientHarness._(
        clientA: clientA,
        clientB: clientB,
        config: config,
      );
    } catch (_) {
      await _safeDisconnect(clientA.sync);
      await _safeDisconnect(clientB.sync);
      clientA.container.dispose();
      clientB.container.dispose();
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _safeDisconnect(clientA.sync);
    await _safeDisconnect(clientB.sync);
    clientA.container.dispose();
    clientB.container.dispose();
  }

  static Future<E2eClientContext> _createClient({
    required String label,
    required String identity,
    required String room,
    required String dataRoomName,
  }) async {
    final identityService = LocalIdentityService(
      UserProfile(id: identity, displayName: label, publicKey: ''),
    );

    final securityService = SecurityService();
    await securityService.initialize();
    final publicKey = await securityService.getPublicKey();
    await identityService.updatePublicKey(base64Encode(publicKey));

    final transferStatsRepository = TransferStatsRepository(
      await SharedPreferences.getInstance(),
    );

    final container = ProviderContainer(
      overrides: [
        crdtServiceProvider.overrideWithValue(CrdtService()),
        identityServiceProvider.overrideWithValue(identityService),
        securityServiceProvider.overrideWithValue(securityService),
        encryptionServiceProvider.overrideWithValue(EncryptionService()),
        secureStorageServiceProvider.overrideWithValue(
          InMemorySecureStorageService(),
        ),
        transferStatsRepositoryProvider.overrideWithValue(
          transferStatsRepository,
        ),
      ],
    );

    final sync = container.read(syncServiceProvider);
    return E2eClientContext(
      label: label,
      identity: identity,
      room: room,
      dataRoomName: dataRoomName,
      container: container,
      sync: sync,
    );
  }

  static Future<String> _fetchToken(String room, String identity) async {
    final uri = Uri.parse(AppConfig.getTokenUrl(room, identity));
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Token fetch failed for $identity: ${response.body}');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected token payload type for $identity');
    }

    final token = payload['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Token missing for $identity');
    }
    return token;
  }

  static Future<void> _safeDisconnect(SyncService sync) async {
    try {
      await sync.disconnect();
    } catch (_) {
      // Best effort teardown.
    }
  }
}

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  bool get isSecure => true;
}

class LocalIdentityService extends IdentityService {
  LocalIdentityService(this._profile);

  UserProfile? _profile;

  @override
  UserProfile? get profile => _profile;

  @override
  bool get isNew => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final existing = _profile;
    if (existing == null) return;
    await saveProfile(
      UserProfile(
        id: existing.id,
        displayName: name,
        publicKey: existing.publicKey,
      ),
    );
  }

  @override
  Future<void> updatePublicKey(String publicKey) async {
    final existing = _profile;
    if (existing == null) return;
    await saveProfile(
      UserProfile(
        id: existing.id,
        displayName: existing.displayName,
        publicKey: publicKey,
      ),
    );
  }
}
