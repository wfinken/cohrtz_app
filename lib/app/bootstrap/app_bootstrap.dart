import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/shared/config/app_config.dart';
import 'package:cohortz/shared/security/encryption_service.dart';
import 'package:cohortz/shared/security/identity_service.dart';
import 'package:cohortz/shared/security/security_service.dart';
import 'package:cohortz/shared/services/background_service.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

Future<ProviderScope> createAppProviderScope({required Widget child}) async {
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

  return ProviderScope(
    overrides: [
      crdtServiceProvider.overrideWithValue(crdtService),
      identityServiceProvider.overrideWith((ref) => identityService),
      encryptionServiceProvider.overrideWithValue(encryptionService),
      transferStatsRepositoryProvider.overrideWithValue(transferStatsRepo),
    ],
    child: child,
  );
}
