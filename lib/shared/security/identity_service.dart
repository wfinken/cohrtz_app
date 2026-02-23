import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import '../../slices/dashboard_shell/models/user_model.dart';
import 'secure_storage_service.dart';

class IdentityService extends ChangeNotifier {
  static const String _profileKey = 'cohrtz_global_profile';

  final ISecureStore _secureStorage;

  IdentityService({ISecureStore? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorageService();

  UserProfile? _profile;
  UserProfile? get profile => _profile;
  bool _isNew = false;
  bool get isNew => _isNew;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    String? profileJson = await _secureStorage.read(_profileKey);

    if (profileJson == null) {
      // Legacy plaintext migration from SharedPreferences.
      final legacy = prefs.getString(_profileKey);
      if (legacy != null && legacy.isNotEmpty) {
        profileJson = legacy;
        await _secureStorage.write(_profileKey, legacy);
      }
    }

    // Remove any legacy plaintext copy after successful secure load/migration.
    if (prefs.containsKey(_profileKey)) {
      await prefs.remove(_profileKey);
    }

    if (profileJson != null) {
      try {
        _profile = UserProfileMapper.fromJson(profileJson);
        Log.i(
          'IdentityService',
          'Loaded existing global profile: ${_profile?.displayName}',
        );
      } catch (e) {
        Log.e('IdentityService', 'Error parsing saved profile', e);
        await _createNewProfile();
      }
    } else {
      await _createNewProfile();
    }
  }

  Future<void> _createNewProfile() async {
    final id = 'user:${const Uuid().v7()}';
    _profile = UserProfile(
      id: id,
      displayName: 'User', // Default name
      publicKey: '', // Will be updated by SecurityService or when linked
    );
    _isNew = true;
    await saveProfile(_profile!);
    Log.i('IdentityService', 'Created new global profile: $id');
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    await _secureStorage.write(_profileKey, profile.toJson());

    // Clear legacy plaintext copy if it still exists.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_profileKey)) {
      await prefs.remove(_profileKey);
    }
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    if (_profile == null) return;
    final updatedProfile = UserProfile(
      id: _profile!.id,
      displayName: name,
      publicKey: _profile!.publicKey,
      avatarBase64: _profile!.avatarBase64,
      bio: _profile!.bio,
    );
    await saveProfile(updatedProfile);
  }

  Future<void> updatePublicKey(String publicKey) async {
    if (_profile == null) return;
    final updatedProfile = UserProfile(
      id: _profile!.id,
      displayName: _profile!.displayName,
      publicKey: publicKey,
      avatarBase64: _profile!.avatarBase64,
      bio: _profile!.bio,
    );
    await saveProfile(updatedProfile);
  }
}
