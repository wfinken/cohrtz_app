import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/secure_storage_service.dart';
import 'logging_service.dart';

class DebugHelper {
  static Future<void> clearAllData() async {
    Log.i('DebugHelper', 'Starting full data wipe...');

    try {
      Log.i('DebugHelper', 'Clearing SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Log.i('DebugHelper', 'SharedPreferences cleared.');

      Log.i('DebugHelper', 'Clearing SecureStorage...');
      final secureStorage = SecureStorageService();
      await secureStorage.deleteAll();
      Log.i('DebugHelper', 'SecureStorage cleared.');

      if (!kIsWeb) {
        Log.i('DebugHelper', 'Deleting database files...');
        final dir = await getApplicationDocumentsDirectory();
        final files = dir.listSync();
        for (final file in files) {
          if (file is File && file.path.endsWith('.db')) {
            try {
              await file.delete();
              Log.i('DebugHelper', 'Deleted: ${file.path}');
            } catch (e) {
              Log.e('DebugHelper', 'Failed to delete ${file.path}', e);
            }
          }
          if (file is File &&
              (file.path.endsWith('.db-shm') ||
                  file.path.endsWith('.db-wal'))) {
            try {
              await file.delete();
              Log.i('DebugHelper', 'Deleted WAL/SHM: ${file.path}');
            } catch (e) {
              Log.e('DebugHelper', 'Failed to delete ${file.path}', e);
            }
          }
        }
        Log.i('DebugHelper', 'Database files deletion process completed.');
      } else {
        Log.w(
          'DebugHelper',
          'Web database deletion is not fully implemented in this helper.',
        );
      }

      Log.i(
        'DebugHelper',
        'Full data wipe completed successfully. App ecosystem destroyed.',
      );
    } catch (e) {
      Log.e('DebugHelper', 'Error during data wipe', e);
      rethrow;
    }
  }
}
