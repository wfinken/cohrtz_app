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
    required this.clients,
    required this.config,
    required this.room,
  });

  final List<E2eClientContext> clients;
  final E2eEnvConfig config;
  final String room;

  E2eClientContext get clientA => clients.first;
  E2eClientContext get clientB => clients[1];

  static Future<TwoClientHarness> start(E2eEnvConfig config) async {
    SharedPreferences.setMockInitialValues({});
    // Clear persisted encrypted blobs so mocked prefs-derived keys always match.
    await SecureStorageService().deleteAll();

    final runId = DateTime.now().microsecondsSinceEpoch;
    final room = '${config.roomPrefix}-$runId';
    final identities = List<String>.generate(
      config.userCount,
      (index) => 'e2e-user-$runId-${index + 1}',
    );
    final clients = <E2eClientContext>[];
    for (var i = 0; i < identities.length; i++) {
      clients.add(
        await _createClient(
          label: 'client${i + 1}',
          identity: identities[i],
          room: room,
          dataRoomName: '${room}__client_${i + 1}',
        ),
      );
    }

    try {
      final tokenResults = <String>[];
      for (final identity in identities) {
        tokenResults.add(await _fetchToken(room, identity));
      }
      for (var i = 0; i < clients.length; i++) {
        final client = clients[i];
        await client.sync.connect(
          tokenResults[i],
          room,
          identity: identities[i],
          friendlyName: room,
          dataRoomName: client.dataRoomName,
        );
      }

      final requiredRemoteParticipants = config.userCount - 1;

      await expectEventually(
        description:
            'all ${config.userCount} clients should connect and discover each other',
        timeout: _connectionTimeout(config.userCount),
        interval: _connectionInterval(config.userCount),
        condition: () async {
          final connectedResults = await Future.wait<bool>(
            clients.map((client) async {
              return client.sync.isConnected &&
                  client.sync.getRemoteParticipantCount(room) >=
                      requiredRemoteParticipants;
            }),
          );
          return connectedResults.every((value) => value);
        },
      );

      await _waitForPairwiseKeys(
        clients: clients,
        room: room,
        identities: identities,
        userCount: config.userCount,
      );

      return TwoClientHarness._(clients: clients, config: config, room: room);
    } catch (_) {
      await Future.wait<void>(
        clients.map((client) => _safeDisconnect(client.sync)),
      );
      for (final client in clients) {
        client.container.dispose();
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    await Future.wait<void>(
      clients.map((client) => _safeDisconnect(client.sync)),
    );
    for (final client in clients) {
      client.container.dispose();
    }
  }

  static Future<E2eClientContext> _createClient({
    required String label,
    required String identity,
    required String room,
    required String dataRoomName,
  }) async {
    final secureStorage = InMemorySecureStorageService();
    final identityService = LocalIdentityService(
      UserProfile(id: identity, displayName: label, publicKey: ''),
    );

    final securityService = SecurityService(secureStorage: secureStorage);
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
        secureStorageServiceProvider.overrideWithValue(secureStorage),
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

Duration _connectionTimeout(int userCount) {
  if (userCount <= 2) {
    return const Duration(seconds: 25);
  }
  final seconds = (userCount * 10).clamp(40, 240);
  return Duration(seconds: seconds);
}

Duration _connectionInterval(int userCount) {
  if (userCount <= 4) {
    return const Duration(milliseconds: 250);
  }
  return const Duration(milliseconds: 450);
}

Future<void> _waitForPairwiseKeys({
  required List<E2eClientContext> clients,
  required String room,
  required List<String> identities,
  required int userCount,
}) async {
  await expectEventually(
    description: 'all $userCount clients should exchange pairwise keys',
    timeout: _connectionTimeout(userCount),
    interval: _connectionInterval(userCount),
    condition: () async {
      var allReady = true;
      final clientsMissingKeys = <E2eClientContext>[];

      for (var i = 0; i < clients.length; i++) {
        final client = clients[i];
        final localIdentity = identities[i];
        final handshake = client.container.read(handshakeHandlerProvider);
        final missingPeerKey = identities.any(
          (remoteIdentity) =>
              remoteIdentity != localIdentity &&
              handshake.getEncryptionKey(room, remoteIdentity) == null,
        );
        if (missingPeerKey) {
          allReady = false;
          clientsMissingKeys.add(client);
        }
      }

      if (!allReady) {
        await Future.wait(
          clientsMissingKeys.map(
            (client) => client.container
                .read(handshakeHandlerProvider)
                .requestHandshake(room, force: true),
          ),
        );
        await Future.wait(
          clients.map(
            (client) => client.container
                .read(syncProtocolProvider)
                .requestSync(room, force: true),
          ),
        );
        await Future.wait(
          clients.map(
            (client) => client.container
                .read(dataBroadcasterProvider)
                .retryPendingUnicast(room),
          ),
        );
      }

      return allReady;
    },
  );
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
