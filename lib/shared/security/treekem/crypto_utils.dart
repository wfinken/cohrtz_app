import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Cryptographic utilities for TreeKEM.
/// Based on RFC 9420.
class TreekemCrypto {
  static final _hmac = Hmac.sha256();
  static final _x25519 = X25519();

  /// Derive-Secret(secret, label) -> secret
  static Future<List<int>> deriveSecret(List<int> secret, String label) async {
    // For simplicity, we'll use a standard HKDF-Expand for now.
    final hkdf = Hkdf(hmac: _hmac, outputLength: 32);
    final prk = secret; // In TreeKEM, the secret is already a PRK
    final output = await hkdf.deriveKey(
      secretKey: SecretKey(prk),
      info: utf8.encode('MLS 1.0 $label'),
    );
    return await output.extractBytes();
  }

  /// Derive-Key-Pair(secret) -> KeyPair
  static Future<SimpleKeyPair> deriveKeyPair(List<int> secret) async {
    return await _x25519.newKeyPairFromSeed(secret);
  }

  /// Encrypt a secret for a public key using a simplified HPKE-like construction.
  static Future<List<int>> hpkeSeal(
    List<int> publicKey,
    List<int> plaintext,
  ) async {
    final remotePublicKey = SimplePublicKey(
      publicKey,
      type: KeyPairType.x25519,
    );

    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: remotePublicKey,
    );

    final hkdf = Hkdf(hmac: _hmac, outputLength: 32);
    final symmetricKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode('TreeKEM-HPKE'),
    );

    // Encrypt
    final aes = AesGcm.with256bits();
    final nonce = aes.newNonce();
    final secretBox = await aes.encrypt(
      plaintext,
      secretKey: symmetricKey,
      nonce: nonce,
    );

    // Output: ephemeral public key + nonce + mac + ciphertext
    final builder = BytesBuilder();
    builder.add(ephemeralPublicKey.bytes);
    builder.add(nonce);
    builder.add(secretBox.mac.bytes);
    builder.add(secretBox.cipherText);
    return builder.takeBytes();
  }

  /// Decrypt a secret using the corresponding private key.
  static Future<List<int>> hpkeOpen(
    SimpleKeyPair keyPair,
    List<int> sealedPacket,
  ) async {
    const pubKeyLen = 32;
    const nonceLen = 12;
    const macLen = 16;

    if (sealedPacket.length < pubKeyLen + nonceLen + macLen) {
      throw ArgumentError('Sealed packet is too short');
    }

    final ephemeralPublicKeyBytes = sealedPacket.sublist(0, pubKeyLen);
    final nonce = sealedPacket.sublist(pubKeyLen, pubKeyLen + nonceLen);
    final macBytes = sealedPacket.sublist(
      pubKeyLen + nonceLen,
      pubKeyLen + nonceLen + macLen,
    );
    final cipherText = sealedPacket.sublist(pubKeyLen + nonceLen + macLen);

    final remotePublicKey = SimplePublicKey(
      ephemeralPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    // Derive shared secret
    try {
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: remotePublicKey,
      );

      // Derive symmetric key
      final hkdf = Hkdf(hmac: _hmac, outputLength: 32);
      final symmetricKey = await hkdf.deriveKey(
        secretKey: sharedSecret,
        info: utf8.encode('TreeKEM-HPKE'),
      );
      // Decrypt
      final aes = AesGcm.with256bits();
      return await aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: symmetricKey,
      );
    } catch (e) {
      rethrow;
    }
  }
}
