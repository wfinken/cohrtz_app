import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/shared/config/app_config.dart';
import 'package:cohortz/shared/security/encryption_service.dart';
import 'package:cohortz/shared/security/identity_service.dart';
import 'package:cohortz/shared/security/secure_storage_service.dart';
import 'package:cohortz/shared/security/security_service.dart';
import 'package:cohortz/shared/services/background_service.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

class AppBootstrapOptions {
  const AppBootstrapOptions({
    this.initializeBackgroundService = AppConfig.enableBackgroundService,
    this.initializeSecurity = true,
    this.initializeCrdt = true,
    this.providerOverrides = const <dynamic>[],
  });

  final bool initializeBackgroundService;
  final bool initializeSecurity;
  final bool initializeCrdt;
  final List<dynamic> providerOverrides;
}

Future<ProviderScope> createAppProviderScope({
  required Widget child,
  AppBootstrapOptions? options,
}) async {
  final resolvedOptions = options ?? const AppBootstrapOptions();

  Log.i('Main', 'Initializing critical services...');
  await initializeBackgroundService(
    enabled: resolvedOptions.initializeBackgroundService,
  );
  final crdtService = CrdtService();
  final identityService = IdentityService();
  final secureStorageService = SecureStorageService();
  final securityService = SecurityService(secureStorage: secureStorageService);
  final encryptionService = EncryptionService();

  Log.i('Main', 'Initializing TransferStatsRepository...');
  final prefs = await SharedPreferences.getInstance();
  final transferStatsRepo = TransferStatsRepository(prefs);

  if (resolvedOptions.initializeSecurity) {
    Log.i('Main', 'Initializing IdentityService...');
    await identityService.initialize();
  } else {
    Log.i('Main', 'Skipping security bootstrap (test/runtime override).');
  }

  if (resolvedOptions.initializeCrdt) {
    Log.i('Main', 'Initializing CrdtService default node...');
    final nodeId =
        identityService.profile?.id ?? 'unknown_boot_${const Uuid().v4()}';
    await crdtService.initialize(nodeId, 'default');
  } else {
    Log.i('Main', 'Skipping CRDT bootstrap (test/runtime override).');
  }

  Log.i('Main', 'Initialization complete. Running App.');

  return ProviderScope(
    overrides: [
      crdtServiceProvider.overrideWithValue(crdtService),
      identityServiceProvider.overrideWith((ref) => identityService),
      secureStorageServiceProvider.overrideWithValue(secureStorageService),
      securityServiceProvider.overrideWithValue(securityService),
      encryptionServiceProvider.overrideWithValue(encryptionService),
      transferStatsRepositoryProvider.overrideWithValue(transferStatsRepo),
      ...resolvedOptions.providerOverrides,
    ],
    child: child,
  );
}
