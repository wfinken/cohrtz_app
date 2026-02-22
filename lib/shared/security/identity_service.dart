import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import '../../slices/dashboard_shell/models/user_model.dart';

class IdentityService extends ChangeNotifier {
  UserProfile? _profile;
  UserProfile? get profile => _profile;
  bool _isNew = false;
  bool get isNew => _isNew;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('cohrtz_global_profile');

    if (profileJson != null) {
      try {
        _profile = UserProfileMapper.fromJson(profileJson);
        Log.i(
          'IdentityService',
          'Loaded existing global profile: ${_profile?.displayName}',
        );
      } catch (e) {
        Log.e('IdentityService', 'Error parsing saved profile', e);
        await _createNewProfile(prefs);
      }
    } else {
      await _createNewProfile(prefs);
    }
  }

  Future<void> _createNewProfile(SharedPreferences prefs) async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cohrtz_global_profile', profile.toJson());
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
