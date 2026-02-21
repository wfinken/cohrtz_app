import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'core/services/background_service.dart';
import 'core/app_config.dart';
import 'core/providers.dart';
import 'core/security/security_service.dart';
import 'core/security/identity_service.dart';
import 'core/security/encryption_service.dart';
import 'core/utils/logging_service.dart';
import 'core/theme/app_theme.dart';
import 'features/sync/infrastructure/crdt_service.dart';
import 'features/sync/data/transfer_stats_repository.dart';
import 'features/dashboard/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Log.i('Main', 'Initializing critical services...');
  await initializeBackgroundService(enabled: AppConfig.enableBackgroundService);
  final crdtService = CrdtService();
  final identityService = IdentityService();
  final securityService = SecurityService();
  final encryptionService = EncryptionService();

  Log.i('Main', 'Initializing TransferStatsRepository...');
  final prefs = await SharedPreferences.getInstance();
  final transferStatsRepo = TransferStatsRepository(prefs);

  Log.i('Main', 'Initializing IdentityService...');
  await identityService.initialize();
  Log.i('Main', 'Initializing SecurityService...');
  await securityService.initialize();

  Log.i('Main', 'Linking Public Key to Identity...');
  final pubKey = await securityService.getPublicKey();
  await identityService.updatePublicKey(base64Encode(pubKey));

  Log.i('Main', 'Initializing CrdtService default node...');
  final nodeId =
      identityService.profile?.id ?? 'unknown_boot_${const Uuid().v4()}';
  await crdtService.initialize(nodeId, 'default');
  Log.i('Main', 'Initialization complete. Running App.');

  runApp(
    ProviderScope(
      overrides: [
        crdtServiceProvider.overrideWithValue(crdtService),
        identityServiceProvider.overrideWith((ref) => identityService),
        encryptionServiceProvider.overrideWithValue(encryptionService),
        transferStatsRepositoryProvider.overrideWithValue(transferStatsRepo),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activityNotificationBootstrapProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cohrtz',
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
