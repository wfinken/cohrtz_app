import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cohortz/shared/config/app_config.dart';
import '../../../shared/security/security_service.dart';
import '../../../shared/security/secure_storage_service.dart';
import '../../../shared/utils/jwt_utils.dart';
import '../../../shared/utils/logging_service.dart';
import 'crdt_service.dart';
import 'group_manager.dart';

import 'package:http/http.dart' as http;
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';

class ConnectionManager extends ChangeNotifier {
  final CrdtService _crdtService;
  final SecurityService _securityService;
  final SecureStorageService _secureStorage;
  final GroupManager _groupManager;
  final String _nodeId;

  // roomName -> Room
  final Map<String, Room> _rooms = {};
  final Map<String, StreamSubscription<Uint8List>> _crdtSubscriptions = {};

  // Track rooms with in-progress connections
  final Set<String> _connectingRooms = {};

  final Map<String, String> _localParticipantIdsByRoom = {};
  String? _activeRoomName; // The room currently being viewed
  final Map<String, ConnectionState> _lastStates = {};

  Timer? _pruningTimer;
  Timer? _reconnectJanitorTimer;
  bool _isRunningReconnectionJanitor = false;

  final Function(String roomName, DataReceivedEvent event) onDataReceived;
  final Function(String roomName, ParticipantConnectedEvent event)
  onParticipantConnected;
  final Function(String roomName, ParticipantDisconnectedEvent event)
  onParticipantDisconnected;
  final Function(ConnectionManager manager, String roomName)
  onRoomConnectionStateChanged;
  final Function(String roomName, Uint8List data) onLocalDataChanged;

  // Dependencies for initializing room-specific services (passed from SyncService or managed here?
  // SyncService managed CRDT/TreeKEM init. ConnectionManager should probably trigger a callback "onReadyToSync"?)
  final Future<void> Function(String roomName, bool isHost) onInitializeSync;
  final void Function(String roomName) onCleanupSync;

  ConnectionManager({
    required CrdtService crdtService,
    required SecurityService securityService,
    required SecureStorageService secureStorage,
    required GroupManager groupManager,
    required String nodeId,
    required this.onDataReceived,
    required this.onParticipantConnected,
    required this.onParticipantDisconnected,
    required this.onRoomConnectionStateChanged,
    required this.onLocalDataChanged,
    required this.onInitializeSync,
    required this.onCleanupSync,
  }) : _crdtService = crdtService,
       _securityService = securityService,
       _secureStorage = secureStorage,
       _groupManager = groupManager,
       _nodeId = nodeId;

  Room? getRoom(String roomName) => _rooms[roomName];
  String? get activeRoomName => _activeRoomName;
  String? get localParticipantId {
    final active = _activeRoomName;
    if (active == null) return null;
    final resolved = resolveLocalParticipantIdForRoom(active);
    return resolved.isEmpty ? null : resolved;
  }

  String? getLocalParticipantIdForRoom(String roomName) {
    final resolved = resolveLocalParticipantIdForRoom(roomName);
    return resolved.isEmpty ? null : resolved;
  }

  String resolveLocalParticipantIdForRoom(String roomName) {
    if (roomName.isEmpty) return '';

    final cached = _localParticipantIdsByRoom[roomName];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final livekitIdentity = _rooms[roomName]?.localParticipant?.identity;
    if (livekitIdentity != null && livekitIdentity.isNotEmpty) {
      _localParticipantIdsByRoom[roomName] = livekitIdentity;
      return livekitIdentity;
    }

    final knownIdentity = _groupManager.findGroup(roomName)['identity'];
    if (knownIdentity != null && knownIdentity.isNotEmpty) {
      return knownIdentity;
    }

    return '';
  }

  bool isConnected(String roomName) =>
      _rooms[roomName]?.connectionState == ConnectionState.connected;

  bool isActiveRoomConnected() =>
      _rooms[_activeRoomName]?.connectionState == ConnectionState.connected;

  bool isActiveRoomConnecting() =>
      _rooms[_activeRoomName]?.connectionState == ConnectionState.connecting ||
      _rooms[_activeRoomName]?.connectionState == ConnectionState.reconnecting;

  bool get isAnyRoomConnected =>
      _rooms.values.any((r) => r.connectionState == ConnectionState.connected);

  Set<String> get connectedRoomNames => _rooms.keys
      .where((k) => _rooms[k]?.connectionState == ConnectionState.connected)
      .toSet();

  Map<String, RemoteParticipant> getRemoteParticipants(String roomName) =>
      _rooms[roomName]?.remoteParticipants ?? {};

  void setActiveRoom(String roomName) {
    if (_activeRoomName != roomName) {
      Log.d('ConnectionManager', 'Switching active room to: $roomName');
      _activeRoomName = roomName;
      notifyListeners();
    }
  }

  Future<void> _cancelCrdtSubscription(String roomName) async {
    final subscription = _crdtSubscriptions.remove(roomName);
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (e) {
      Log.e(
        'ConnectionManager',
        'Error cancelling CRDT stream for $roomName',
        e,
      );
    }
  }

  Future<void> _disconnectTrackedRoom(String roomName, Room room) async {
    await _cancelCrdtSubscription(roomName);
    _localParticipantIdsByRoom.remove(roomName);
    _lastStates.remove(roomName);
    onCleanupSync(roomName);
    try {
      await room.disconnect();
    } catch (e) {
      Log.e('ConnectionManager', 'Error disconnecting $roomName', e);
    }

    if (identical(_rooms[roomName], room)) {
      _rooms.remove(roomName);
    }
  }

  Future<void> disconnectAll() async {
    Log.i('ConnectionManager', 'Disconnecting all rooms...');
    for (final entry in _rooms.entries.toList()) {
      await _disconnectTrackedRoom(entry.key, entry.value);
    }
    _rooms.clear();
    _connectingRooms.clear();
    _localParticipantIdsByRoom.clear();
    _lastStates.clear();
    _activeRoomName = null;
    _pruningTimer?.cancel();
    _reconnectJanitorTimer?.cancel();
  }

  Future<void> disconnectRoom(String roomName) async {
    final room = _rooms[roomName];
    if (room != null) {
      Log.i('ConnectionManager', 'Disconnecting from room: $roomName');
      await _disconnectTrackedRoom(roomName, room);
    } else {
      await _cancelCrdtSubscription(roomName);
      _lastStates.remove(roomName);
    }
    _connectingRooms.remove(roomName);
    _localParticipantIdsByRoom.remove(roomName);
    if (_activeRoomName == roomName) {
      _activeRoomName = null;
      notifyListeners();
    }
  }

  bool _isSuspended = false;

  Future<void> suspendNetwork() async {
    if (_isSuspended) return;
    _isSuspended = true;

    Log.i('ConnectionManager', 'Suspending network for sleep/background...');
    _pruningTimer?.cancel();
    _reconnectJanitorTimer?.cancel();

    for (final entry in _rooms.entries.toList()) {
      try {
        Log.d('ConnectionManager', 'Suspending room: ${entry.value.name}');
        await _disconnectTrackedRoom(entry.key, entry.value);
      } catch (e) {
        Log.e(
          'ConnectionManager',
          'Error suspending room ${entry.value.name}',
          e,
        );
      }
    }
    _rooms.clear();
    _connectingRooms.clear();
    _localParticipantIdsByRoom.clear();
    _lastStates.clear();
    // Do NOT clear _activeRoomName, so UI stays ready to resume.
    notifyListeners();
  }

  bool _isRestoring = false;

  Future<void> restoreNetwork() async {
    if (!_isSuspended) return;
    if (_isRestoring) return;
    _isRestoring = true;

    Log.i('ConnectionManager', 'Restoring network from sleep/background...');
    // Debounce/Delay to let network settle
    await Future.delayed(const Duration(seconds: 3));

    await _groupManager.loadKnownGroups();
    startJanitors();
    Log.d('ConnectionManager', 'Triggering immediate reconnection check.');
    await _runReconnectionJanitor();

    _isRestoring = false;
    _isSuspended = false;
  }

  Future<void> connect(
    String token,
    String roomName, {
    required String dataRoomName,
    String? identity,
    String? inviteCode,
    String? friendlyName,
    bool isHost = false,
    bool setActive = true,
  }) async {
    await _connectToRoom(
      token,
      roomName,
      dataRoomName: dataRoomName,
      identity: identity,
      syncData: true,
      friendlyName: friendlyName,
      isInviteRoom: false,
      isHost: isHost,
      setActive: setActive,
    );
  }

  Future<void> joinInviteRoom(
    String token,
    String groupName, {
    String? identity,
    bool setActive = false,
  }) async {
    Log.i('ConnectionManager', 'Joining Invite Room: $groupName');
    await _connectToRoom(
      token,
      groupName,
      dataRoomName: groupName,
      identity: identity ?? getLocalParticipantIdForRoom(groupName) ?? _nodeId,
      syncData: false,
      isInviteRoom: true,
      setActive: setActive,
    );
  }

  Future<void> ensureInviteRoomConnectedForDataRoom(String dataRoomName) async {
    final dataGroup = _groupManager.knownGroups.firstWhere(
      (g) => g['roomName'] == dataRoomName,
      orElse: () => {},
    );
    if (dataGroup.isEmpty) return;

    final inviteRoomName = dataGroup['friendlyName'];
    final identity = dataGroup['identity'];
    if (inviteRoomName == null ||
        inviteRoomName.isEmpty ||
        inviteRoomName == dataRoomName) {
      return;
    }
    if (isConnected(inviteRoomName) ||
        _connectingRooms.contains(inviteRoomName)) {
      return;
    }
    if (identity == null || identity.isEmpty) return;

    try {
      var token = await _secureStorage.read('token_$inviteRoomName');
      if (token == null || JwtUtils.isExpired(token)) {
        token = await _fetchToken(inviteRoomName, identity);
      }
      await joinInviteRoom(
        token,
        inviteRoomName,
        identity: identity,
        setActive: false,
      );
    } catch (e) {
      Log.e(
        'ConnectionManager',
        'Failed to ensure invite room $inviteRoomName for data room $dataRoomName',
        e,
      );
    }
  }

  /// Internal primitive for connection
  Future<void> _connectToRoom(
    String token,
    String roomName, {
    required String dataRoomName,
    String? identity,
    bool syncData = true,
    String? friendlyName,
    bool isInviteRoom = false,
    bool isHost = false,
    bool setActive = true,
  }) async {
    // Guard: Connection in progress (Check early)
    if (_connectingRooms.contains(roomName)) {
      Log.w(
        'ConnectionManager',
        'Connection to $roomName already in progress. Skipping duplicate request.',
      );
      return;
    }
    _connectingRooms.add(roomName);

    try {
      var effectiveToken = token;
      // Validate token structure (must have 'iss' claim)
      if (!JwtUtils.isValid(effectiveToken)) {
        Log.w(
          'ConnectionManager',
          'Token for $roomName is invalid/malformed (missing iss?). Fetching fresh token...',
        );
        if (identity != null) {
          effectiveToken = await _fetchToken(roomName, identity);
        } else {
          Log.e(
            'ConnectionManager',
            'Cannot fetch fresh token for $roomName: Identity is null.',
          );
          return;
        }
      } else if (JwtUtils.isExpired(effectiveToken) && identity != null) {
        Log.w(
          'ConnectionManager',
          'Token expired for $roomName. Fetching a fresh token...',
        );
        effectiveToken = await _fetchToken(roomName, identity);
      }

      try {
        final payload = JwtUtils.decodePayload(effectiveToken);
        Log.i(
          'ConnectionManager',
          'Connecting to $roomName with Token Issuer: ${payload['iss']} / Identity: ${payload['sub']}',
        );
      } catch (e) {
        Log.w(
          'ConnectionManager',
          'Error decoding token payload for logging: $e',
        );
      }

      // Save connection details via GroupManager
      // (Moved inside try-finally to ensure _connectingRooms is cleaned up)
      final prefs = await SharedPreferences.getInstance();
      if (setActive) {
        Log.i(
          'ConnectionManager',
          'Saving last active group: $roomName ($friendlyName)',
        );
        await prefs.setString('last_group_name', roomName);
        if (identity != null) {
          await prefs.setString('last_group_identity', identity);
        }
        final resolvedFriendlyName =
            friendlyName ?? _groupManager.getFriendlyName(roomName);
        await prefs.setString('last_group_friendly_name', resolvedFriendlyName);
        await _secureStorage.write('last_group_token', effectiveToken);
        await prefs.setString('last_group_is_invite', isInviteRoom.toString());
        await prefs.setString('last_group_is_host', isHost.toString());
      } else {
        Log.i(
          'ConnectionManager',
          'Not saving active group (setActive=false) for $roomName',
        );
      }

      // Update GroupManager
      await _groupManager.saveKnownGroup(
        roomName,
        dataRoomName,
        identity ?? 'unknown',
        friendlyName: friendlyName,
        isInviteRoom: isInviteRoom,
        isHost: isHost,
        token: effectiveToken,
      );

      if (identity != null && identity.isNotEmpty) {
        _localParticipantIdsByRoom[roomName] = identity;
      }

      // Guard: Skip if already connected
      if (_rooms.containsKey(roomName) &&
          _rooms[roomName]!.connectionState == ConnectionState.connected) {
        if (syncData && setActive) setActiveRoom(roomName);
        return; // Cleanup handled in finally
      }

      // If a stale/disconnected room object exists, tear it down before replacing.
      final existingRoom = _rooms[roomName];
      if (existingRoom != null) {
        Log.d(
          'ConnectionManager',
          'Cleaning up stale room before reconnect: $roomName (${existingRoom.connectionState})',
        );
        await _disconnectTrackedRoom(roomName, existingRoom);
      }

      // Initialize Sync Dependencies (CRDT / TreeKEM)
      if (syncData) {
        final localIdentity = resolveLocalParticipantIdForRoom(roomName);
        await _crdtService.initialize(
          localIdentity.isNotEmpty ? localIdentity : _nodeId,
          roomName,
          databaseName: dataRoomName,
        );
        await onInitializeSync(roomName, isHost);
      }

      if (syncData && setActive) _activeRoomName = roomName;
      notifyListeners();

      await _securityService.initializeForGroup(roomName);

      // Monitor for GroupSettings changes to update group metadata
      await _cancelCrdtSubscription(roomName);
      _crdtSubscriptions[roomName] = _crdtService.getStream(roomName).listen((
        data,
      ) async {
        try {
          // Broadcast local changes to the room
          onLocalDataChanged(roomName, data);

          // We can inspect the raw data to see if it's for 'group_settings'
          // Or simpler: just query the table anytime we get an update?
          // The event is raw bytes (changeset). Decoding it is costly if we do it for everything.
          // Better: Perform a check periodically or just optimize the update trigger.
          // Actually, let's just do a targeted check when connection is established and then
          // relies on a lightweight check.
          // For now, let's just trigger the check. It's a single row lookup usually.
          await _updateGroupMetadata(roomName);
        } catch (e) {
          Log.e(
            'ConnectionManager',
            'Error processing CRDT update for $roomName',
            e,
          );
        }
      });
      // Initial check
      await _updateGroupMetadata(roomName);
      // Connect Loop
      int retryCount = 0;
      const maxRetries = 3;
      bool connected = false;
      bool forceRelay = false;

      while (retryCount < maxRetries && !connected) {
        // Cleanup previous attempt
        if (_rooms[roomName] != null) {
          try {
            await _rooms[roomName]!.disconnect();
          } catch (_) {}
          _rooms.remove(roomName);
        }

        // Create Room
        final room = Room(
          roomOptions: const RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
              maxFrameRate: 30,
              params: VideoParametersPresets.h720_169,
            ),
            defaultAudioCaptureOptions: AudioCaptureOptions(
              echoCancellation: true,
              noiseSuppression: true,
            ),
            dynacast: true,
            adaptiveStream: true,
          ),
        );
        _rooms[roomName] = room;

        // Listeners
        final roomListener = room.createListener();
        roomListener
          ..on<DataReceivedEvent>((event) => onDataReceived(roomName, event))
          ..on<ParticipantConnectedEvent>((event) {
            onParticipantConnected(roomName, event);
            notifyListeners();
          })
          ..on<ParticipantDisconnectedEvent>((event) {
            onParticipantDisconnected(roomName, event);
            notifyListeners();
          })
          ..on<RoomEvent>((e) {
            final newState = room.connectionState;
            if (_lastStates[roomName] != newState) {
              _lastStates[roomName] = newState;
              Log.d(
                'ConnectionManager',
                'State changed for $roomName: $newState. Triggering callback.',
              );
              onRoomConnectionStateChanged(this, roomName);
              notifyListeners();
            }
          });

        try {
          // IMPORTANT: Do NOT set iceServers here. The LiveKit SDK only uses
          // server-provided TURN credentials when iceServers == null.
          // Setting iceServers (even just STUN) silently discards the server's
          // TURN config, breaking relay/NAT traversal.
          final connectOptions = forceRelay
              ? ConnectOptions(
                  autoSubscribe: true,
                  rtcConfiguration: const RTCConfiguration(
                    iceTransportPolicy: RTCIceTransportPolicy.relay,
                  ),
                )
              : const ConnectOptions(autoSubscribe: true);

          // Diagnostic check
          await _checkConnectivity(AppConfig.livekitUrl);

          Log.d(
            'ConnectionManager',
            'Attempting to connect to room $roomName (DataRoom: $dataRoomName / InviteRoom: $isInviteRoom)...',
          );

          await room
              .connect(
                AppConfig.livekitUrl,
                effectiveToken,
                connectOptions: connectOptions,
              )
              .timeout(
                const Duration(
                  seconds: 35,
                ), // Increased to 35s to allow for 15s internal timeouts + setup
                onTimeout: () => throw TimeoutException(
                  'ConnectionManager outer timeout after 35s',
                ),
              );
          connected = true;
        } catch (e) {
          retryCount++;
          Log.w(
            'ConnectionManager',
            'Connection failed ($retryCount/$maxRetries): $e',
          );

          try {
            await room.disconnect();
          } catch (_) {}

          final err = e.toString();
          if (err.contains('MediaConnectException') ||
              err.contains('PeerConnection to connect') ||
              err.contains('ice')) {
            forceRelay = true;
            Log.w(
              'ConnectionManager',
              'ICE connectivity issue detected. Retrying with TURN/relay only.',
            );
          }
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: retryCount * 2));
          } else {
            // Cleanup on fail
            await _disconnectTrackedRoom(roomName, room);
            rethrow;
          }
        }
      }

      final localId = _rooms[roomName]?.localParticipant?.identity;
      if (localId != null && localId.isNotEmpty) {
        _localParticipantIdsByRoom[roomName] = localId;
      }
      notifyListeners();

      startJanitors();
    } finally {
      // Critical: Always remove from connecting set
      _connectingRooms.remove(roomName);
    }
  }

  void startJanitors() {
    _pruningTimer?.cancel();
    _pruningTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _runJanitorPruning(),
    );
    Future.delayed(const Duration(seconds: 10), _runJanitorPruning);

    _reconnectJanitorTimer?.cancel();
    _reconnectJanitorTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _runReconnectionJanitor(),
    );
  }

  Future<void> _runReconnectionJanitor() async {
    if (_isRunningReconnectionJanitor) return;
    _isRunningReconnectionJanitor = true;

    // Note: GroupManager needs an getAllGroups or similar exposure
    // Logic from SyncService: iterate knownDataGroups and knownInviteGroups, check connectivity
    try {
      final dataGroups = List<Map<String, String?>>.from(
        _groupManager.knownGroups,
      );
      for (final group in dataGroups) {
        final roomName = group['roomName'];
        if (roomName != null && !isConnected(roomName)) {
          if (!_connectingRooms.contains(roomName)) {
            Log.i(
              'ConnectionManager',
              'Janitor reconnecting Data Room: $roomName',
            );
            await _reconnectGroup(group, isInviteRoom: false);
          }
        }
      }

      final inviteGroups = List<Map<String, String?>>.from(
        _groupManager.knownInviteGroups,
      );
      for (final group in inviteGroups) {
        final roomName = group['roomName'];
        if (roomName != null && !isConnected(roomName)) {
          if (!_connectingRooms.contains(roomName)) {
            Log.i(
              'ConnectionManager',
              'Janitor reconnecting Invite Room: $roomName',
            );
            await _reconnectGroup(group, isInviteRoom: true);
          }
        }
      }
    } finally {
      _isRunningReconnectionJanitor = false;
    }
  }

  @override
  void dispose() {
    _pruningTimer?.cancel();
    _reconnectJanitorTimer?.cancel();
    for (final subscription in _crdtSubscriptions.values.toList()) {
      unawaited(subscription.cancel());
    }
    _crdtSubscriptions.clear();
    for (final room in _rooms.values.toList()) {
      unawaited(room.disconnect().catchError((_) {}));
    }
    _rooms.clear();
    _connectingRooms.clear();
    _localParticipantIdsByRoom.clear();
    _lastStates.clear();
    super.dispose();
  }

  Future<void> _reconnectGroup(
    Map<String, String?> group, {
    required bool isInviteRoom,
  }) async {
    final roomName = group['roomName'];
    final identity = group['identity'];
    if (roomName == null || identity == null) return;

    try {
      var token = await _secureStorage.read('token_$roomName');
      if (token == null ||
          !JwtUtils.isValid(token) ||
          JwtUtils.isExpired(token)) {
        // Need fetchToken.
        Log.w(
          'ConnectionManager',
          'Janitor: Cached token for $roomName is missing or invalid. Fetching new one.',
        );
        token = await _fetchToken(roomName, identity);
      }

      await _connectToRoom(
        token,
        roomName,
        dataRoomName: group['dataRoomName'] ?? roomName,
        identity: identity,
        syncData: !isInviteRoom,
        friendlyName: group['friendlyName'],
        isInviteRoom: isInviteRoom,
        isHost: group['isHost'] == 'true',
        setActive: false,
      );
    } catch (e) {
      Log.e('ConnectionManager', 'Janitor failed to reconnect $roomName', e);
    }
  }

  Future<void> _runJanitorPruning() async {
    // This requires GroupSettings logic which is somewhat domain specific.
    // But it's maintenance.
    // Logic: query CRDT for group_settings, prune expired.
    // ConnectionManager knows about CRDT service.

    for (final roomName in _rooms.keys) {
      // Only if data group
      bool isData = _groupManager.knownGroups.any(
        (g) => g['roomName'] == roomName,
      );
      if (isData) {
        await _pruneExpiredInvites(roomName);
      }
    }
  }

  @visibleForTesting
  Future<void> pruneExpiredInvitesForTesting(String roomName) {
    return _pruneExpiredInvites(roomName);
  }

  Future<void> _pruneExpiredInvites(String roomName) async {
    try {
      final results = await _crdtService.query(
        roomName,
        'SELECT id, value FROM group_settings',
      );
      if (results.isEmpty) return;

      bool changed = false;
      for (final row in results) {
        final id = row['id'] as String;
        final jsonStr = row['value'] as String?;
        if (jsonStr == null) continue;

        final settings = GroupSettingsMapper.fromJson(jsonStr);
        final initialCount = settings.invites.length;
        final validInvites = settings.invites.where((i) => i.isValid).toList();

        if (validInvites.length != initialCount) {
          Log.i(
            'ConnectionManager',
            'Janitor: Pruning ${initialCount - validInvites.length} expired invites in $roomName',
          );
          final updatedSettings = settings.copyWith(invites: validInvites);
          await _crdtService.put(
            roomName,
            id,
            // toJson already returns a JSON string; do not double-encode.
            updatedSettings.toJson(),
            tableName: 'group_settings',
          );
          changed = true;
        }
      }

      if (changed) {
        // Notify sync service to broadcast consistency check?
        // ConnectionManager doesn't invoke broadcaster directly.
        // We might need a callback for "Data Changed that requires broadcast".
        // For now, we skip the consistency check broadcast here or expose a callback.
        // SyncService observes CRDT stream changes, so maybe it's automatic?
        // SyncService: `_crdtService.getStream(roomName).listen` -> broadcast.
        // So yes, `put` triggers the stream, which triggers broadcast in SyncService!
      }
    } catch (e) {
      Log.e(
        'ConnectionManager',
        'Janitor: Error pruning invites in $roomName',
        e,
      );
    }
  }

  Future<String> _fetchToken(String room, String identity) async {
    final uri = Uri.parse(AppConfig.getTokenUrl(room, identity));
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['token'];
    } else {
      throw Exception('Failed to fetch token: ${response.body}');
    }
  }

  Future<void> _updateGroupMetadata(String roomName) async {
    try {
      // Query ALL group_settings rows to handle migration/legacy cases robustly
      final results = await _crdtService.query(
        roomName,
        'SELECT id, value FROM group_settings',
      );

      if (results.isEmpty) return;

      GroupSettings? settings;
      // Prefer canonical 'group_settings' id
      try {
        final canonical = results.firstWhere(
          (r) => r['id'] == 'group_settings',
          orElse: () =>
              results.first, // Fallback to any row if canonical missing
        );
        if (canonical['value'] != null) {
          settings = GroupSettingsMapper.fromJson(canonical['value'] as String);
        }
      } catch (e) {
        // Fallback or empty
      }

      if (settings != null) {
        final newName = settings.name;
        if (newName.isNotEmpty) {
          final currentGroup = _groupManager.findGroup(roomName);
          final currentName = currentGroup['friendlyName'] ?? '';
          final currentAvatar = currentGroup['avatarBase64'] ?? '';
          final currentDescription = currentGroup['description'] ?? '';

          final shouldUpdateMetadata =
              currentName != newName ||
              currentAvatar != settings.avatarBase64 ||
              currentDescription != settings.description;

          if (shouldUpdateMetadata) {
            Log.i('ConnectionManager', 'Updating group metadata for $roomName');
            await _groupManager.saveKnownGroup(
              roomName,
              currentGroup['dataRoomName'] ?? roomName,
              currentGroup['identity'] ?? 'unknown',
              friendlyName: newName,
              avatarBase64: settings.avatarBase64,
              description: settings.description,
              isInviteRoom: currentGroup['isInviteRoom'] == 'true',
              isHost: currentGroup['isHost'] == 'true',
              token:
                  null, // Don't overwrite token unless we have a new one (passed null keeps existing)
            );
          }
        }
      }
    } catch (e) {
      Log.e(
        'ConnectionManager',
        'Failed to update group metadata for $roomName',
        e,
      );
    }
  }

  Future<void> _checkConnectivity(String url) async {
    try {
      if (kIsWeb) return; // Skip raw socket checks on web

      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : 443;

      Log.d('ConnectionManager', 'Checking connectivity to $host:$port...');

      final stopwatch = Stopwatch()..start();
      final lookup = await InternetAddress.lookup(host);
      Log.d(
        'ConnectionManager',
        'DNS resolved in ${stopwatch.elapsedMilliseconds}ms: ${lookup.map((a) => a.address).join(', ')}',
      );

      if (lookup.isNotEmpty) {
        final socket = await Socket.connect(
          lookup.first,
          port,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        Log.d(
          'ConnectionManager',
          'TCP connection successful to $host in ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    } catch (e) {
      Log.w('ConnectionManager', 'Connectivity check failed: $e');
    }
  }
}
