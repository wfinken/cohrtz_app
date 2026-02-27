import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import 'package:cohortz/slices/sync/contracts/group_descriptor.dart';
import '../../../shared/security/secure_storage_service.dart';

/// Manages persistence and retrieval of known groups (data rooms and invite rooms).
///
/// Extracted from SyncService to improve modularity and testability.
class GroupManager {
  static const String _knownGroupsKey = 'known_groups';
  static const String _knownInviteRoomsKey = 'known_invite_rooms';
  static const String _lastGroupNameKey = 'last_group_name';
  static const String _lastGroupIdentityKey = 'last_group_identity';
  static const String _lastGroupIsInviteKey = 'last_group_is_invite';
  static const String _lastGroupIsHostKey = 'last_group_is_host';
  static const String _lastGroupFriendlyNameKey = 'last_group_friendly_name';
  static const String _lastGroupTokenKey = 'last_group_token';

  final ISecureStore _secureStorage;
  final VoidCallback? onGroupsChanged;

  List<Map<String, String?>> _knownDataGroups = [];
  List<Map<String, String?>> _knownInviteGroups = [];
  Future<void>? _loadFuture;

  GroupManager({required ISecureStore secureStorage, this.onGroupsChanged})
    : _secureStorage = secureStorage;

  Future<String?> _readSecureStringWithLegacy(
    SharedPreferences prefs,
    String key,
  ) async {
    final secureValue = await _secureStorage.read(key);
    if (secureValue != null) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
      return secureValue;
    }

    final legacyValue = prefs.getString(key);
    if (legacyValue != null) {
      await _secureStorage.write(key, legacyValue);
      await prefs.remove(key);
    }
    return legacyValue;
  }

  Future<void> _removeLegacyIfPresent(
    SharedPreferences prefs,
    String key,
  ) async {
    if (prefs.containsKey(key)) {
      await prefs.remove(key);
    }
  }

  List<Map<String, String?>> _sanitizeGroups(
    List<Map<String, String?>> groups,
  ) {
    return groups.map((g) {
      final m = Map<String, String?>.from(g);
      m.remove('token');
      return m;
    }).toList();
  }

  Future<void> _persistKnownGroups() async {
    await _secureStorage.write(
      _knownGroupsKey,
      jsonEncode(_sanitizeGroups(_knownDataGroups)),
    );
    await _secureStorage.write(
      _knownInviteRoomsKey,
      jsonEncode(_sanitizeGroups(_knownInviteGroups)),
    );
  }

  /// Returns an unmodifiable view of known data groups.
  List<Map<String, String?>> get knownGroups =>
      List.unmodifiable(_knownDataGroups);

  /// Returns an unmodifiable view of known invite groups.
  List<Map<String, String?>> get knownInviteGroups =>
      List.unmodifiable(_knownInviteGroups);

  /// Returns all known groups (data + invite).
  List<Map<String, String?>> get allKnownGroups =>
      List.unmodifiable([..._knownDataGroups, ..._knownInviteGroups]);

  List<GroupDescriptor> get knownGroupDescriptors =>
      _knownDataGroups.map(GroupDescriptor.fromMap).toList(growable: false);

  List<GroupDescriptor> get knownInviteGroupDescriptors =>
      _knownInviteGroups.map(GroupDescriptor.fromMap).toList(growable: false);

  List<GroupDescriptor> get allKnownGroupDescriptors => [
    ...knownGroupDescriptors,
    ...knownInviteGroupDescriptors,
  ];

  /// Returns a copy of known data groups (safe for iteration during modification).
  Future<List<Map<String, String?>>> getKnownGroups() async {
    await loadKnownGroups();
    return List<Map<String, String?>>.from(_knownDataGroups);
  }

  Future<KnownGroupsSnapshot> getKnownGroupsSnapshot() async {
    await loadKnownGroups();
    return KnownGroupsSnapshot(
      dataGroups: knownGroupDescriptors,
      inviteGroups: knownInviteGroupDescriptors,
    );
  }

  /// Loads known groups from persistent storage.
  Future<void> loadKnownGroups() async {
    if (_loadFuture != null) return _loadFuture;
    _loadFuture = _loadKnownGroupsInternal();
    return _loadFuture;
  }

  Future<void> _loadKnownGroupsInternal() async {
    final prefs = await SharedPreferences.getInstance();

    final dataJson = await _readSecureStringWithLegacy(prefs, _knownGroupsKey);
    if (dataJson != null) {
      final List<dynamic> list = jsonDecode(dataJson);
      _knownDataGroups = list.map((e) => Map<String, String?>.from(e)).toList();
      // Hydrate tokens from secure storage (or migrate legacy tokens)
      for (var group in _knownDataGroups) {
        final roomName = group['roomName'];
        if (roomName != null) {
          String? token = await _secureStorage.read('token_$roomName');
          if (token == null && group['token'] != null) {
            // MIGRATION: Move legacy plaintext token to secure storage
            token = group['token'];
            await _secureStorage.write('token_$roomName', token!);
          }
          if (token != null) {
            group['token'] = token;
          }
        }
      }
    } else {
      _knownDataGroups = [];
    }

    final inviteJson = await _readSecureStringWithLegacy(
      prefs,
      _knownInviteRoomsKey,
    );
    if (inviteJson != null) {
      final List<dynamic> list = jsonDecode(inviteJson);
      _knownInviteGroups = list
          .map((e) => Map<String, String?>.from(e))
          .toList();
      // Hydrate tokens from secure storage
      for (var group in _knownInviteGroups) {
        final roomName = group['roomName'];
        if (roomName != null) {
          String? token = await _secureStorage.read('token_$roomName');
          if (token == null && group['token'] != null) {
            // MIGRATION
            token = group['token'];
            await _secureStorage.write('token_$roomName', token!);
          }
          if (token != null) {
            group['token'] = token;
          }
        }
      }
    } else {
      _knownInviteGroups = [];
    }

    // Safety check: Remove misplaced groups
    _knownDataGroups.removeWhere((g) => g['isInviteRoom'] == 'true');
    _knownInviteGroups.removeWhere((g) => g['isInviteRoom'] != 'true');

    // Persist sanitized secure copies and clear any legacy plaintext JSON.
    await _persistKnownGroups();
    await _removeLegacyIfPresent(prefs, _knownGroupsKey);
    await _removeLegacyIfPresent(prefs, _knownInviteRoomsKey);

    onGroupsChanged?.call();
  }

  /// Checks if there's a saved group for auto-join.
  Future<bool> get hasSavedGroup async {
    final prefs = await SharedPreferences.getInstance();
    final roomName = await _readSecureStringWithLegacy(
      prefs,
      _lastGroupNameKey,
    );
    return roomName != null && roomName.isNotEmpty;
  }

  /// Gets saved connection details for auto-join.
  Future<Map<String, String?>?> getSavedConnectionDetails(
    String livekitUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final roomName = await _readSecureStringWithLegacy(
      prefs,
      _lastGroupNameKey,
    );
    final hasKey = roomName != null && roomName.isNotEmpty;
    Log.d(
      'GroupManager',
      'Checking saved details. HasKey: $hasKey, Name: $roomName',
    );
    if (!hasKey) return null;

    final identity = await _readSecureStringWithLegacy(
      prefs,
      _lastGroupIdentityKey,
    );
    final isInvite = await _readSecureStringWithLegacy(
      prefs,
      _lastGroupIsInviteKey,
    );
    final isHost = await _readSecureStringWithLegacy(
      prefs,
      _lastGroupIsHostKey,
    );
    final friendlyName = await _readSecureStringWithLegacy(
      prefs,
      _lastGroupFriendlyNameKey,
    );

    // Keep only encrypted copy of host flag when present.
    final hostFlag = prefs.getString(_lastGroupIsHostKey);
    if (hostFlag != null && hostFlag.isNotEmpty) {
      await _secureStorage.write(_lastGroupIsHostKey, hostFlag);
      await prefs.remove(_lastGroupIsHostKey);
    }

    return {
      'url': livekitUrl,
      'roomName': roomName,
      'identity': identity,
      'isInviteRoom': isInvite,
      'isHost': isHost,
      'friendlyName': friendlyName ?? await _lookupFriendlyName(roomName),
      'token': await _secureStorage.read(_lastGroupTokenKey),
    };
  }

  Future<String?> _lookupFriendlyName(String? roomName) async {
    if (roomName == null) return null;
    await loadKnownGroups();
    return getFriendlyName(roomName);
  }

  /// Saves or updates a known group entry.
  Future<void> saveKnownGroup(
    String roomName,
    String dataRoomName,
    String identity, {
    String? friendlyName,
    String? avatarBase64,
    String? description,
    bool isInviteRoom = false,
    bool isHost = false,
    String? token,
  }) async {
    final existingDataEntry = _knownDataGroups.firstWhere(
      (g) => g['roomName'] == roomName,
      orElse: () => {},
    );
    final existingInviteEntry = _knownInviteGroups.firstWhere(
      (g) => g['roomName'] == roomName,
      orElse: () => {},
    );
    final existingIsHost =
        existingDataEntry['isHost'] == 'true' ||
        existingInviteEntry['isHost'] == 'true';
    final effectiveIsHost = isHost || existingIsHost;

    final entry = {
      'roomName': roomName,
      'dataRoomName': dataRoomName,
      'identity': identity,
      'token': token,
      'isHost': effectiveIsHost.toString(),
      'friendlyName':
          friendlyName ??
          existingDataEntry['friendlyName'] ??
          existingInviteEntry['friendlyName'] ??
          roomName,
      'avatarBase64':
          avatarBase64 ??
          existingDataEntry['avatarBase64'] ??
          existingInviteEntry['avatarBase64'] ??
          '',
      'description':
          description ??
          existingDataEntry['description'] ??
          existingInviteEntry['description'] ??
          '',
      'isInviteRoom': isInviteRoom.toString(),
      'lastJoined': DateTime.now().toIso8601String(),
    };

    if (token != null) {
      await _secureStorage.write('token_$roomName', token);
    }

    if (isInviteRoom) {
      _knownDataGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownInviteGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownInviteGroups.insert(0, entry);
    } else {
      _knownInviteGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownDataGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownDataGroups.insert(0, entry);
    }

    await _persistKnownGroups();

    // Remove legacy plaintext copies after secure persist.
    final prefs = await SharedPreferences.getInstance();
    await _removeLegacyIfPresent(prefs, _knownGroupsKey);
    await _removeLegacyIfPresent(prefs, _knownInviteRoomsKey);

    onGroupsChanged?.call();
  }

  /// Gets the friendly name for a room.
  String getFriendlyName(String? roomName) {
    if (roomName == null || roomName.isEmpty) return 'Cohrtz';
    final dataEntry = _knownDataGroups.firstWhere(
      (g) => g['roomName'] == roomName,
      orElse: () => {},
    );
    if (dataEntry.isNotEmpty && dataEntry['friendlyName'] != null) {
      return dataEntry['friendlyName']!;
    }
    final inviteEntry = _knownInviteGroups.firstWhere(
      (g) => g['roomName'] == roomName,
      orElse: () => {},
    );
    if (inviteEntry.isNotEmpty && inviteEntry['friendlyName'] != null) {
      return inviteEntry['friendlyName']!;
    }
    return roomName;
  }

  /// Removes a group from persistence.
  Future<void> forgetGroup(String roomName) async {
    // Find entries before removal
    final dataEntry = _knownDataGroups.firstWhere(
      (g) => g['roomName'] == roomName,
      orElse: () => {},
    );
    final inviteEntry = _knownInviteGroups.firstWhere(
      (g) => g['roomName'] == roomName,
      orElse: () => {},
    );

    final friendlyName =
        dataEntry['friendlyName'] ?? inviteEntry['friendlyName'];
    final dataRoomName =
        dataEntry['dataRoomName'] ?? inviteEntry['dataRoomName'];

    // Remove from memory
    _knownDataGroups.removeWhere(
      (g) =>
          g['roomName'] == roomName ||
          (friendlyName != null && g['friendlyName'] == friendlyName) ||
          (dataRoomName != null && g['dataRoomName'] == dataRoomName),
    );
    _knownInviteGroups.removeWhere(
      (g) =>
          g['roomName'] == roomName ||
          (friendlyName != null && g['friendlyName'] == friendlyName) ||
          (dataRoomName != null && g['dataRoomName'] == dataRoomName),
    );

    // Persist changes securely.
    await _persistKnownGroups();
    await _secureStorage.delete('token_$roomName');

    // Clear last group if it was this one
    final prefs = await SharedPreferences.getInstance();
    final lastGroupName = await _readSecureStringWithLegacy(
      prefs,
      _lastGroupNameKey,
    );
    if (lastGroupName == roomName ||
        (friendlyName != null && lastGroupName == friendlyName) ||
        (dataRoomName != null && lastGroupName == dataRoomName)) {
      await _secureStorage.delete(_lastGroupNameKey);
      await _secureStorage.delete(_lastGroupIdentityKey);
      await _secureStorage.delete(_lastGroupIsInviteKey);
      await _secureStorage.delete(_lastGroupFriendlyNameKey);
      await _secureStorage.delete(_lastGroupIsHostKey);
      await _secureStorage.delete(_lastGroupTokenKey);

      await _removeLegacyIfPresent(prefs, _lastGroupNameKey);
      await _removeLegacyIfPresent(prefs, _lastGroupIdentityKey);
      await _removeLegacyIfPresent(prefs, _lastGroupIsInviteKey);
      await _removeLegacyIfPresent(prefs, _lastGroupFriendlyNameKey);
      await _removeLegacyIfPresent(prefs, _lastGroupIsHostKey);
      await _removeLegacyIfPresent(prefs, _lastGroupTokenKey);
    }

    await _removeLegacyIfPresent(prefs, _knownGroupsKey);
    await _removeLegacyIfPresent(prefs, _knownInviteRoomsKey);

    onGroupsChanged?.call();
  }

  /// Finds group entry by room name.
  Map<String, String?> findGroup(String roomName) {
    return _knownDataGroups.firstWhere(
      (g) => g['roomName'] == roomName,
      orElse: () => _knownInviteGroups.firstWhere(
        (g) => g['roomName'] == roomName,
        orElse: () => {},
      ),
    );
  }

  GroupDescriptor? findGroupDescriptor(String roomName) {
    final map = findGroup(roomName);
    if (map.isEmpty) return null;
    return GroupDescriptor.fromMap(map);
  }
}
