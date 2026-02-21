import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/shared/utils/jwt_utils.dart';
import 'dart:convert';

void main() {
  group('JwtUtils', () {
    String createMockToken(Map<String, dynamic> payload) {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
      );
      final payloadStr = base64Url.encode(utf8.encode(jsonEncode(payload)));
      return '$header.$payloadStr.signature';
    }

    test('decodePayload should extract data correctly', () {
      final payload = {
        'sub': '1234567890',
        'name': 'John Doe',
        'iat': 1516239022,
      };
      final token = createMockToken(payload);

      final result = JwtUtils.decodePayload(token);
      expect(result['sub'], '1234567890');
      expect(result['name'], 'John Doe');
    });

    test('isExpired should return true for expired token', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = {'exp': nowSeconds - 100}; // Expired 100 seconds ago
      final token = createMockToken(payload);

      expect(JwtUtils.isExpired(token), isTrue);
    });

    test(
      'isExpired should return true for token about to expire (within buffer)',
      () {
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final payload = {'exp': nowSeconds + 30}; // Expires in 30 seconds
        final token = createMockToken(payload);

        // Default buffer is 60 seconds, so it should be considered "expired"
        expect(JwtUtils.isExpired(token), isTrue);
      },
    );

    test('isExpired should return false for valid token', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = {'exp': nowSeconds + 3600}; // Expires in 1 hour
      final token = createMockToken(payload);

      expect(JwtUtils.isExpired(token), isFalse);
    });

    test('isExpired should return true for invalid token format', () {
      expect(JwtUtils.isExpired('invalid-token'), isTrue);
    });
  });
}
