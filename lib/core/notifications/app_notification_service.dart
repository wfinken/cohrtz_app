import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../security/secure_storage_service.dart';

class AppNotificationService extends ChangeNotifier
    with WidgetsBindingObserver {
  AppNotificationService(
    this._secureStorage, {
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final SecureStorageService _secureStorage;
  final FlutterLocalNotificationsPlugin _plugin;

  static const _storageKey = 'app_notifications';

  static const AndroidNotificationChannel
  _activityChannel = AndroidNotificationChannel(
    'cohortz_activity_updates',
    'Activity Updates',
    description:
        'Notifications about tasks, vault items, calendar events, chat activity, polls, and member changes.',
    importance: Importance.high,
  );

  bool _initialized = false;
  Future<void>? _initializationFuture;
  int _nextId = 1;
  bool _isAppFocused = false;
  bool _observerAttached = false;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  void _log(String message) {
    // debugPrint('[AppNotificationService] $message');
  }

  Future<void> initialize() async {
    if (kIsWeb) {
      _log('initialize skipped on web.');
      return;
    }

    // Load persisted notifications independently of the plugin initialization
    await loadNotifications();

    if (_initialized) {
      _log('initialize skipped (already initialized).');
      return;
    }
    if (_initializationFuture != null) {
      _log('initialize awaiting in-flight initialization.');
      return _initializationFuture;
    }

    _log('initialize starting.');
    _initializationFuture = _initializeInternal();
    try {
      await _initializationFuture;
      _log('initialize completed.');
    } catch (error, stackTrace) {
      _log('initialize failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> loadNotifications() async {
    try {
      final jsonString = await _secureStorage.read(_storageKey);
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _notifications = decoded
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        // Sort by timestamp descending
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }
    } catch (e) {
      _log('Failed to load notifications: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      // Keep only the last 50 notifications to prevent storage bloat
      if (_notifications.length > 50) {
        _notifications = _notifications.sublist(0, 50);
      }
      final jsonString = jsonEncode(
        _notifications.map((n) => n.toJson()).toList(),
      );
      await _secureStorage.write(_storageKey, jsonString);
      notifyListeners();
    } catch (e) {
      _log('Failed to save notifications: $e');
    }
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _secureStorage.delete(_storageKey);
    notifyListeners();
  }

  Future<void> clearCategory(AppNotificationCategory category) async {
    _notifications.removeWhere((n) => n.category == category);
    await _saveNotifications();
  }

  Future<void> delete(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(read: true);
      await _saveNotifications();
    }
  }

  Future<void> _initializeInternal() async {
    if (_initialized || kIsWeb) return;
    _log('internal initialization started.');
    _attachLifecycleObserver();

    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open app',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(settings);
    _log('plugin initialize() completed.');

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      _log('android platform plugin unavailable.');
    } else {
      await androidPlugin.createNotificationChannel(_activityChannel);
      _log('android channel created: ${_activityChannel.id}');
      final androidPermission = await androidPlugin
          .requestNotificationsPermission();
      _log('android permission request result: $androidPermission');
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosPermission = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    _log('ios permission request result: $iosPermission');

    final macosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macosPermission = await macosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    _log('macos permission request result: $macosPermission');

    _initialized = true;
    _log('internal initialization finished. initialized=$_initialized');
  }

  void _attachLifecycleObserver() {
    if (_observerAttached) return;
    WidgetsBinding.instance.addObserver(this);
    _observerAttached = true;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isAppFocused = lifecycle == AppLifecycleState.resumed;
    _log(
      'lifecycle observer attached. state=$lifecycle focused=$_isAppFocused',
    );
  }

  @override
  void dispose() {
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
      _log('lifecycle observer detached.');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppFocused = state == AppLifecycleState.resumed;
  }

  Future<void> showNewTask({
    required String roomName,
    required String title,
    required String assignedTo,
  }) {
    return _show(
      title: 'New Task in $roomName',
      body: '$title (Assigned to $assignedTo)',
      category: AppNotificationCategory.task,
    );
  }

  Future<void> showTaskCompleted({
    required String roomName,
    required String title,
  }) {
    return _show(
      title: 'Task Completed in $roomName',
      body: title,
      category: AppNotificationCategory.task,
    );
  }

  Future<void> showNewVaultItem({
    required String roomName,
    required String label,
    required String type,
  }) {
    return _show(
      title: 'New Vault Item in $roomName',
      body: '$label ($type)',
      category: AppNotificationCategory.vault,
    );
  }

  Future<void> showNewCalendarEvent({
    required String roomName,
    required String title,
    required String location,
  }) {
    return _show(
      title: 'New Calendar Event in $roomName',
      body: location.isEmpty ? title : '$title at $location',
      category: AppNotificationCategory.event,
    );
  }

  Future<void> showUserJoined({
    required String roomName,
    required String displayName,
  }) {
    return _show(
      title: 'Member Joined $roomName',
      body: '$displayName joined the group.',
      category: AppNotificationCategory.system,
    );
  }

  Future<void> showUserLeft({
    required String roomName,
    required String displayName,
  }) {
    return _show(
      title: 'Member Left $roomName',
      body: '$displayName left the group.',
      category: AppNotificationCategory.system,
    );
  }

  Future<void> showNewChatMessage({
    required String groupName,
    required String chatName,
    required String senderName,
    required String messagePreview,
  }) {
    final safeGroup = groupName.trim().isEmpty ? 'Group' : groupName.trim();
    final safeChat = chatName.trim().isEmpty ? 'Chat' : chatName.trim();
    return _show(
      title: 'New Message in $safeGroup ($safeChat)',
      body: '$senderName: $messagePreview',
      category: AppNotificationCategory.message,
    );
  }

  Future<void> showNewPoll({
    required String roomName,
    required String question,
  }) {
    return _show(
      title: 'New Poll in $roomName',
      body: question,
      category: AppNotificationCategory.system,
    );
  }

  Future<void> showPollClosed({
    required String roomName,
    required String question,
    required String status,
  }) {
    return _show(
      title: 'Poll $status in $roomName',
      body: question,
      category: AppNotificationCategory.system,
    );
  }

  Future<void> showPollVoteUpdate({
    required String roomName,
    required String question,
    required int totalVotes,
    required int memberCount,
  }) {
    return _show(
      title: 'New Vote in $roomName',
      body: '$question ($totalVotes/$memberCount votes)',
      category: AppNotificationCategory.system,
    );
  }

  Future<void> _show({
    required String title,
    required String body,
    AppNotificationCategory category = AppNotificationCategory.system,
  }) async {
    // Always add to internal list and save, regardless of focus or platform
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString() + _nextId.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      category: category,
    );

    _notifications.insert(0, notification);
    await _saveNotifications();

    if (kIsWeb) {
      _log('show skipped on web: "$title"');
      return;
    }
    _log('show requested: "$title"');

    // Attempt system notification
    // Don't await initialize() here to block adding to list, but do it to show system notif
    await initialize();

    if (!_initialized) {
      _log('show skipped because initialization is incomplete: "$title"');
      return;
    }
    if (_isAppFocused) {
      _log('show skipped because app is focused: "$title"');
      return;
    }

    final notificationId = _nextId++;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _activityChannel.id,
        _activityChannel.name,
        channelDescription: _activityChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      linux: LinuxNotificationDetails(),
    );

    try {
      await _plugin.show(notificationId, title, body, details);
      _log('show succeeded (#$notificationId): "$title"');
    } catch (error, stackTrace) {
      _log('show failed (#$notificationId): $error');
      debugPrintStack(stackTrace: stackTrace);
      // Don't rethrow, as we successfully saved it internally
    }
  }
}

enum AppNotificationCategory { task, event, vault, message, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final AppNotificationCategory category;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.category = AppNotificationCategory.system,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? read,
    AppNotificationCategory? category,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'category': category.name,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      read: json['read'] as bool? ?? false,
      category: AppNotificationCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String?),
        orElse: () => AppNotificationCategory.system,
      ),
    );
  }
}
