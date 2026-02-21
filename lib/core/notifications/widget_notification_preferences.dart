import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class WidgetNotificationPreferences {
  static const String _keyPrefix = 'widget_notifications_';

  SharedPreferences? _prefs;
  final Map<String, bool> _cache = {};
  final Map<String, StreamController<bool>> _controllers = {};

  Future<SharedPreferences> _ensurePrefs() async {
    final existing = _prefs;
    if (existing != null) return existing;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  String _normalizeGroupId(String groupId) {
    final trimmed = groupId.trim();
    return trimmed.isEmpty ? 'default' : trimmed;
  }

  String _key({required String groupId, required String widgetType}) {
    final normalizedGroupId = _normalizeGroupId(groupId);
    final normalizedType = widgetType.trim().toLowerCase();
    return '$_keyPrefix${normalizedGroupId}_$normalizedType';
  }

  Future<bool> isEnabled({
    required String groupId,
    required String widgetType,
  }) async {
    final key = _key(groupId: groupId, widgetType: widgetType);
    if (_cache.containsKey(key)) return _cache[key] ?? true;

    final prefs = await _ensurePrefs();
    final value = prefs.getBool(key) ?? true;
    _cache[key] = value;
    return value;
  }

  Future<void> setEnabled({
    required String groupId,
    required String widgetType,
    required bool enabled,
  }) async {
    final prefs = await _ensurePrefs();
    final key = _key(groupId: groupId, widgetType: widgetType);
    _cache[key] = enabled;
    await prefs.setBool(key, enabled);
    _controllers[key]?.add(enabled);
  }

  Stream<bool> watchEnabled({
    required String groupId,
    required String widgetType,
  }) async* {
    final key = _key(groupId: groupId, widgetType: widgetType);
    yield await isEnabled(groupId: groupId, widgetType: widgetType);

    final controller = _controllers.putIfAbsent(
      key,
      () => StreamController<bool>.broadcast(),
    );
    yield* controller.stream;
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
