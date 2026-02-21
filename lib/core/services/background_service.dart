import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeBackgroundService({required bool enabled}) async {
  if (!enabled) return;
  if (Platform.isAndroid || Platform.isIOS) {
    final service = FlutterBackgroundService();

    // Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'cohortz_foreground',
      'Cohrtz Background Sync',
      description: 'Foreground sync status and important background updates.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'cohortz_foreground',
        initialNotificationTitle: 'Cohrtz',
        initialNotificationContent: 'Preparing background sync',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  String? lastForegroundContent;
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        final now = DateTime.now();
        final content =
            'Background sync active (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})';
        if (content != lastForegroundContent) {
          lastForegroundContent = content;
          service.setForegroundNotificationInfo(
            title: 'Cohrtz',
            content: content,
          );
        }
      }
    }

    service.invoke('update', {
      'current_date': DateTime.now().toIso8601String(),
      'device': 'mobile',
    });
  });
}
