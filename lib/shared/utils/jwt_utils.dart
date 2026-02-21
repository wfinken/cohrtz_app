import 'dart:convert';

class JwtUtils {
  /// Decodes the payload of a JWT token.
  /// Note: This does not verify the signature.
  static Map<String, dynamic> decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWT token format');
    }

    final payload = parts[1];
    var normalizedPayload = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalizedPayload));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  /// Checks if a JWT token is expired or will expire within [bufferSeconds].
  static bool isExpired(String token, {int bufferSeconds = 60}) {
    try {
      final payload = decodePayload(token);
      if (!payload.containsKey('exp')) {
        return false; // No expiration claim, assume not expired
      }

      final exp = payload['exp'] as int;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now().add(Duration(seconds: bufferSeconds));

      return now.isAfter(expiryDate);
    } catch (_) {
      return true; // If we can't decode it, treat it as expired
    }
  }

  /// Checks if a JWT token is valid (not expired and structurally sound for LiveKit).
  static bool isValid(String token) {
    try {
      if (isExpired(token)) return false;
      final payload = decodePayload(token);
      // LiveKit requires 'iss' (API Key) and 'video' claims usually, but 'iss' is critical for auth.
      if (!payload.containsKey('iss') || payload['iss'] == null) return false;
      return true;
    } catch (_) {
      return false;
    }
  }
}
