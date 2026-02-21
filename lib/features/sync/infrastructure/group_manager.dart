import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cohortz/core/utils/logging_service.dart';
import '../../../core/security/secure_storage_service.dart';

/// Manages persistence and retrieval of known groups (data rooms and invite rooms).
///
/// Extracted from SyncService to improve modularity and testability.
class GroupManager {
  final SecureStorageService _secureStorage;
  final VoidCallback? onGroupsChanged;

  List<Map<String, String?>> _knownDataGroups = [];
  List<Map<String, String?>> _knownInviteGroups = [];
  Future<void>? _loadFuture;

  GroupManager({
    required SecureStorageService secureStorage,
    this.onGroupsChanged,
  }) : _secureStorage = secureStorage;

  /// Returns an unmodifiable view of known data groups.
  List<Map<String, String?>> get knownGroups =>
      List.unmodifiable(_knownDataGroups);

  /// Returns an unmodifiable view of known invite groups.
  List<Map<String, String?>> get knownInviteGroups =>
      List.unmodifiable(_knownInviteGroups);

  /// Returns all known groups (data + invite).
  List<Map<String, String?>> get allKnownGroups =>
      List.unmodifiable([..._knownDataGroups, ..._knownInviteGroups]);

  /// Returns a copy of known data groups (safe for iteration during modification).
  Future<List<Map<String, String?>>> getKnownGroups() async {
    await loadKnownGroups();
    return List<Map<String, String?>>.from(_knownDataGroups);
  }

  /// Loads known groups from persistent storage.
  Future<void> loadKnownGroups() async {
    if (_loadFuture != null) return _loadFuture;
    _loadFuture = _loadKnownGroupsInternal();
    return _loadFuture;
  }

  Future<void> _loadKnownGroupsInternal() async {
    final prefs = await SharedPreferences.getInstance();

    final dataJson = prefs.getString('known_groups');
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

    final inviteJson = prefs.getString('known_invite_rooms');
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

    onGroupsChanged?.call();
  }

  /// Checks if there's a saved group for auto-join.
  Future<bool> get hasSavedGroup async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('last_group_name');
  }

  /// Gets saved connection details for auto-join.
  Future<Map<String, String?>?> getSavedConnectionDetails(
    String livekitUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final hasKey = prefs.containsKey('last_group_name');
    final lastGroup = prefs.getString('last_group_name');
    Log.d(
      'GroupManager',
      'Checking saved details. HasKey: $hasKey, Name: $lastGroup',
    );
    if (!hasKey) return null;

    return {
      'url': livekitUrl,
      'roomName': prefs.getString('last_group_name'),
      'identity': prefs.getString('last_group_identity'),
      'isInviteRoom': prefs.getString('last_group_is_invite'),
      'friendlyName':
          prefs.getString('last_group_friendly_name') ??
          await _lookupFriendlyName(prefs.getString('last_group_name')),
      'token': await _secureStorage.read('last_group_token'),
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
    bool isInviteRoom = false,
    bool isHost = false,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'roomName': roomName,
      'dataRoomName': dataRoomName,
      'identity': identity,
      'token': token,
      'isHost': isHost.toString(),
      'friendlyName':
          friendlyName ??
          _knownDataGroups.firstWhere(
            (g) => g['roomName'] == roomName,
            orElse: () => {},
          )['friendlyName'] ??
          _knownInviteGroups.firstWhere(
            (g) => g['roomName'] == roomName,
            orElse: () => {},
          )['friendlyName'] ??
          roomName,
      'isInviteRoom': isInviteRoom.toString(),
      'lastJoined': DateTime.now().toIso8601String(),
    };

    if (token != null) {
      await _secureStorage.write('token_$roomName', token);
    }

    List<Map<String, String?>> sanitize(List<Map<String, String?>> groups) {
      return groups.map((g) {
        final m = Map<String, String?>.from(g);
        m.remove('token');
        return m;
      }).toList();
    }

    if (isInviteRoom) {
      _knownDataGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownInviteGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownInviteGroups.insert(0, entry);

      await prefs.setString(
        'known_invite_rooms',
        jsonEncode(sanitize(_knownInviteGroups)),
      );
      await prefs.setString(
        'known_groups',
        jsonEncode(sanitize(_knownDataGroups)),
      );
    } else {
      _knownInviteGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownDataGroups.removeWhere((g) => g['roomName'] == roomName);
      _knownDataGroups.insert(0, entry);

      await prefs.setString(
        'known_groups',
        jsonEncode(sanitize(_knownDataGroups)),
      );
      await prefs.setString(
        'known_invite_rooms',
        jsonEncode(sanitize(_knownInviteGroups)),
      );
    }
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
    final prefs = await SharedPreferences.getInstance();

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

    // Persist changes
    await prefs.setString('known_groups', jsonEncode(_knownDataGroups));
    await prefs.setString('known_invite_rooms', jsonEncode(_knownInviteGroups));

    // Clear last group if it was this one
    final lastGroupName = prefs.getString('last_group_name');
    if (lastGroupName == roomName ||
        (friendlyName != null && lastGroupName == friendlyName) ||
        (dataRoomName != null && lastGroupName == dataRoomName)) {
      await prefs.remove('last_group_name');
      await prefs.remove('last_group_identity');
      await prefs.remove('last_group_is_invite');
      await prefs.remove('last_group_friendly_name');
    }

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
}
