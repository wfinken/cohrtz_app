import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/shared/platform/web_page_lifecycle.dart';
import 'package:cohortz/shared/theme/tokens/app_theme.dart';
import 'package:cohortz/slices/dashboard_shell/ui/screens/home_screen.dart';

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  final WebPageLifecycle _webPageLifecycle = WebPageLifecycle();

  @override
  void initState() {
    super.initState();
    _webPageLifecycle.register(() {
      unawaited(ref.read(syncServiceProvider).disconnect());
    });
  }

  @override
  void dispose() {
    _webPageLifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(activityNotificationBootstrapProvider);
    final themeSettings = ref.watch(themeSettingsProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cohrtz',
      themeMode: themeSettings.mode,
      theme: AppTheme.lightForSettings(themeSettings),
      darkTheme: AppTheme.darkForSettings(themeSettings),
      home: const HomeScreen(),
    );
  }
}
