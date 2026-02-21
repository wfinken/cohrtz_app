import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../dashboard/domain/dashboard_models.dart';

class LocalDashboardStorage {
  static const String _keyPrefix = 'dashboard_layout_';

  Future<List<DashboardWidget>> loadWidgets(
    String groupId, {
    int? columns,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (columns != null) {
      final key = '$_keyPrefix${groupId}_${columns}col';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final List<dynamic> decoded = jsonDecode(jsonStr);
          return decoded
              .map(
                (e) => DashboardWidgetMapper.fromMap(e as Map<String, dynamic>),
              )
              .toList();
        } catch (_) {}
      }
    }

    final key = '$_keyPrefix$groupId';
    final jsonStr = prefs.getString(key);

    if (jsonStr == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .map((e) => DashboardWidgetMapper.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveWidgets(
    String groupId,
    List<DashboardWidget> widgets, {
    int? columns,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String key;
    if (columns != null) {
      key = '$_keyPrefix${groupId}_${columns}col';
    } else {
      key = '$_keyPrefix$groupId';
    }

    final jsonStr = jsonEncode(widgets.map((e) => e.toMap()).toList());
    await prefs.setString(key, jsonStr);
  }

  Future<void> saveWidget(
    String groupId,
    DashboardWidget widget, {
    int? columns,
  }) async {
    final widgets = await loadWidgets(groupId, columns: columns);
    final index = widgets.indexWhere((w) => w.id == widget.id);

    if (index != -1) {
      widgets[index] = widget;
    } else {
      widgets.add(widget);
    }

    await saveWidgets(groupId, widgets, columns: columns);
  }

  Future<void> deleteWidget(
    String groupId,
    String widgetId, {
    int? columns,
  }) async {
    final widgets = await loadWidgets(groupId, columns: columns);
    widgets.removeWhere((w) => w.id == widgetId);
    await saveWidgets(groupId, widgets, columns: columns);
  }

  Future<int> getStorageSize(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_keyPrefix$groupId';
    int total = 0;

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final value = prefs.getString(key);
      if (value == null) continue;
      total += utf8.encode(value).length;
    }

    return total;
  }

  // Read Status Logic
  static const String _readStatusPrefix = 'chat_read_status_';
  final _readStatusControllers = <String, StreamController<Map<String, int>>>{};

  Stream<Map<String, int>> watchReadStatus(String groupId) async* {
    // Yield the persisted value first
    yield await loadReadStatus(groupId);

    // Get or create controller for this group
    StreamController<Map<String, int>> controller;
    if (_readStatusControllers.containsKey(groupId)) {
      controller = _readStatusControllers[groupId]!;
    } else {
      controller = StreamController<Map<String, int>>.broadcast();
      _readStatusControllers[groupId] = controller;
    }

    // Then yield updates from the group-specific stream
    yield* controller.stream;
  }

  Future<Map<String, int>> loadReadStatus(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_readStatusPrefix$groupId';
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveReadStatus(
    String groupId,
    String threadId,
    int timestamp,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_readStatusPrefix$groupId';

    final currentStatus = await loadReadStatus(groupId);
    currentStatus[threadId] = timestamp;

    await prefs.setString(key, jsonEncode(currentStatus));

    if (_readStatusControllers.containsKey(groupId)) {
      _readStatusControllers[groupId]!.add(currentStatus);
    }
  }
}
