import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../slices/dashboard_shell/models/user_model.dart';
import 'security_service.dart';

/// Persists local profile metadata per group/room.
///
/// Each group has its own user id + display name + public key snapshot.
class GroupIdentityService {
  GroupIdentityService({required SecurityService securityService})
    : _securityService = securityService;

  final SecurityService _securityService;

  static const _storagePrefix = 'cohrtz_group_identity_';
  static const _legacyGlobalProfileKey = 'cohrtz_global_profile';

  String _storageKey(String groupId) =>
      '$_storagePrefix${Uri.encodeComponent(groupId)}';

  Future<UserProfile?> _loadLegacyGlobalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyGlobalProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfileMapper.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  bool _isPlaceholderName(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'anonymous';
  }

  Future<UserProfile?> loadForGroup(String groupId) async {
    if (groupId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(groupId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfileMapper.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveForGroup(String groupId, UserProfile profile) async {
    if (groupId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(groupId), profile.toJson());
  }

  Future<UserProfile> ensureForGroup({
    required String groupId,
    String? displayName,
    String? avatarBase64,
    String? bio,
    String? fallbackIdentity,
  }) async {
    if (groupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Must not be empty');
    }

    final existing = await loadForGroup(groupId);
    final legacyGlobal = await _loadLegacyGlobalProfile();
    await _securityService.initializeForGroup(groupId);
    final publicKey = base64Encode(
      await _securityService.getPublicKey(groupId: groupId),
    );

    final legacyId = legacyGlobal?.id.trim() ?? '';
    final resolvedId = (existing?.id.isNotEmpty == true)
        ? existing!.id
        : (fallbackIdentity != null && fallbackIdentity.isNotEmpty
              ? fallbackIdentity
              : (legacyId.isNotEmpty ? legacyId : 'user:${const Uuid().v7()}'));

    final trimmed = displayName?.trim() ?? '';
    final existingName = existing?.displayName.trim() ?? '';
    final legacyName = legacyGlobal?.displayName.trim() ?? '';
    final resolvedName = trimmed.isNotEmpty
        ? trimmed
        : (!_isPlaceholderName(existingName)
              ? existingName
              : (legacyName.isNotEmpty ? legacyName : 'User'));
    final resolvedAvatar = avatarBase64?.trim() ?? existing?.avatarBase64 ?? '';
    final resolvedBio = bio?.trim() ?? existing?.bio ?? '';

    final profile = UserProfile(
      id: resolvedId,
      displayName: resolvedName,
      publicKey: publicKey,
      avatarBase64: resolvedAvatar,
      bio: resolvedBio,
    );
    await saveForGroup(groupId, profile);
    return profile;
  }

  Future<UserProfile> regenerateKeysForGroup({
    required String groupId,
    required String displayName,
    String? avatarBase64,
    String? bio,
    required String fallbackIdentity,
  }) async {
    if (groupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Must not be empty');
    }
    await _securityService.resetGroupKeys(groupId);
    return ensureForGroup(
      groupId: groupId,
      displayName: displayName,
      avatarBase64: avatarBase64,
      bio: bio,
      fallbackIdentity: fallbackIdentity,
    );
  }
}
