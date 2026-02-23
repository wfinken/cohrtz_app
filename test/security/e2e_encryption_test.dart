import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cohortz/shared/security/security_service.dart';
import 'package:cohortz/shared/security/encryption_service.dart';
import 'package:cohortz/shared/security/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Encryption Flow', () {
    late SecurityService aliceSecurity;
    late SecurityService bobSecurity;
    late EncryptionService encryptionService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SecureStorageService().deleteAll();

      // We need separate "storages" or just instances.
      // SecurityService uses SharedPreferences singleton.
      // To simulate two different users, we can't easily use the real SecurityService
      // without modifying it to accept a prefix or mock prefs.
      //
      // However, for this test, we can manually use the internal logic if we expose it,
      // OR we can just instantiate them and they will overwrite each other's keys in the global Prefs
      // if we are not careful.
      //
      // ACTUAL FIX: Modifying SecurityService to allow dependency injection of Prefs or Prefix would be best,
      // but for now, let's just initialize Alice, get her keys, then clear prefs, initialize Bob.

      encryptionService = EncryptionService();
    });

    test('Full Key Exchange and Encryption Cycle', () async {
      // 1. Setup Alice
      SharedPreferences.setMockInitialValues({});
      await SecureStorageService().deleteAll();
      aliceSecurity = SecurityService();
      await aliceSecurity.initialize();
      final alicePub = await aliceSecurity.getEncryptionPublicKey();

      // 2. Setup Bob (Clear prefs to force new key generation)
      SharedPreferences.setMockInitialValues({});
      await SecureStorageService().deleteAll();
      bobSecurity = SecurityService();
      await bobSecurity.initialize();
      final bobPub = await bobSecurity.getEncryptionPublicKey();

      // Verify keys are different
      expect(alicePub, isNot(equals(bobPub)));

      // 3. Derive Shared Secrets
      // Alice derives secret using Bob's Public Key
      final salt = utf8.encode('test-room-id');
      final aliceSharedSecret = await aliceSecurity.deriveSharedSecret(
        bobPub,
        salt: salt,
      );
      final aliceKeyBytes = await aliceSharedSecret.extractBytes();

      // Bob derives secret using Alice's Public Key
      // WE MUST RELOAD BOB's KEYPAIR because we cleared prefs?
      // Ah, SecurityService keeps state in memory (`_keyPair`), so Bob is still valid
      // even if underlying prefs are wiped, as long as we don't call initialize() again or it doesn't fail.
      // Wait, we re-instantiated Bob AFTER clearing prefs, so Bob is fine.
      // Alice memory instance is also fine.

      final bobSharedSecret = await bobSecurity.deriveSharedSecret(
        alicePub,
        salt: salt,
      );
      final bobKeyBytes = await bobSharedSecret.extractBytes();

      // 4. Verify Shared Secrets Match
      expect(aliceKeyBytes, equals(bobKeyBytes));

      // 5. Encrypt (Alice sends to Bob)
      final plaintext = utf8.encode('Hello Secure World');
      final encrypted = await encryptionService.encrypt(
        plaintext,
        aliceSharedSecret,
      );

      // 6. Decrypt (Bob receives)
      final decrypted = await encryptionService.decrypt(
        encrypted,
        bobSharedSecret,
      );

      expect(decrypted, equals(plaintext));
      expect(utf8.decode(decrypted), equals('Hello Secure World'));
    });
  });
}
