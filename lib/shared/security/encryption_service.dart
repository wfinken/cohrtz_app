import 'package:cryptography/cryptography.dart';

import 'package:cohortz/shared/utils/logging_service.dart';

/// Encryption service for AES-GCM-256 encryption and Argon2id key derivation.
class EncryptionService {
  final _algorithm = AesGcm.with256bits();

  /// Generates a random 256-bit secret key.
  Future<SecretKey> generateKey() async {
    return await _algorithm.newSecretKey();
  }

  /// Encrypts plaintext bytes using the provided [key].
  /// Returns the combined nonce + ciphertext + mac as bytes.
  Future<List<int>> encrypt(List<int> plaintext, SecretKey key) async {
    Log.d('EncryptionService', 'Encrypting ${plaintext.length} bytes...');
    final secretBox = await _algorithm.encrypt(plaintext, secretKey: key);

    // Format: nonce (12 bytes) + ciphertext + mac (16 bytes)
    return secretBox.concatenation();
  }

  /// Decrypts a combined blob using the provided [key].
  Future<List<int>> decrypt(
    List<int> encryptedBlob,
    SecretKey key, {
    bool silent = false,
  }) async {
    try {
      final secretBox = SecretBox.fromConcatenation(
        encryptedBlob,
        nonceLength: 12,
        macLength: 16,
      );

      final clearText = await _algorithm.decrypt(secretBox, secretKey: key);
      Log.d(
        'EncryptionService',
        'Decrypted successfully: ${clearText.length} bytes',
      );
      return clearText;
    } catch (e) {
      if (!silent) {
        Log.e('EncryptionService', 'Decryption failed', e);
      }
      rethrow;
    }
  }

  /// Derives a key from a password using Argon2id.
  ///
  /// [password] - The user password or passphrase
  /// [salt] - A cryptographically random salt (should be 16+ bytes)
  ///
  /// Argon2id parameters (OWASP recommendations for low-memory devices):
  /// - Memory: 19 MiB (19456 KiB)
  /// - Iterations: 2
  /// - Parallelism: 1
  Future<SecretKey> deriveKeyFromPassword(
    String password,
    List<int> salt,
  ) async {
    Log.d('EncryptionService', 'Deriving key with Argon2id...');

    final kdf = Argon2id(
      parallelism: 1,
      memory: 19456, // 19 MiB
      iterations: 2,
      hashLength: 32,
    );

    final secretKey = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    return secretKey;
  }

  /// Generates a cryptographically random salt.
  /// Returns 16 bytes of random data suitable for key derivation.
  Future<List<int>> generateSalt() async {
    final key = await _algorithm.newSecretKey();
    final bytes = await key.extractBytes();
    return bytes.sublist(0, 16);
  }

  /// Returns true if using secure key derivation (Argon2id).
  bool get isSecureKdf => true;
}
