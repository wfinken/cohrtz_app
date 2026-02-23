import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:cohortz/shared/profile/avatar_processing_service.dart';
import 'package:cohortz/shared/profile/profile_constants.dart';

void main() {
  group('AvatarProcessingService', () {
    test('prepareBytesForCropping downsizes large source images', () {
      final source = img.Image(width: 3200, height: 1800);
      img.fill(source, color: img.ColorRgb8(42, 120, 225));
      final encoded = Uint8List.fromList(img.encodePng(source));

      final prepared = AvatarProcessingService.prepareBytesForCropping(
        encoded,
        maxInputPixels: 1200,
        reencodeThresholdBytes: 1024,
      );
      final decodedPrepared = img.decodeImage(prepared);

      expect(decodedPrepared, isNotNull);
      expect(
        decodedPrepared!.width > decodedPrepared.height
            ? decodedPrepared.width
            : decodedPrepared.height,
        lessThanOrEqualTo(1200),
      );
    });

    test('prepareBytesForCropping keeps smaller images untouched', () {
      final source = img.Image(width: 420, height: 260);
      img.fill(source, color: img.ColorRgb8(42, 120, 225));
      final encoded = Uint8List.fromList(img.encodePng(source));

      final prepared = AvatarProcessingService.prepareBytesForCropping(
        encoded,
        maxInputPixels: 1200,
        reencodeThresholdBytes: 1024 * 1024 * 8,
      );

      expect(prepared, same(encoded));
    });

    test('processes valid image into bounded base64 payload', () {
      final source = img.Image(width: 420, height: 260);
      img.fill(source, color: img.ColorRgb8(42, 120, 225));
      final encoded = Uint8List.fromList(img.encodePng(source));

      final result = AvatarProcessingService.processAvatarBytes(encoded);

      expect(result.base64Data, isNotEmpty);
      expect(
        result.base64Data.length,
        lessThanOrEqualTo(kAvatarMaxBase64Length),
      );
      expect(result.encodedBytes, greaterThan(0));
    });

    test('throws decode exception for invalid image payload', () {
      final invalid = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]);

      expect(
        () => AvatarProcessingService.processAvatarBytes(invalid),
        throwsA(isA<AvatarDecodeException>()),
      );
    });

    test('throws too large exception when max length is impossible', () {
      final source = img.Image(width: 250, height: 250);
      img.fill(source, color: img.ColorRgb8(200, 45, 33));
      final encoded = Uint8List.fromList(img.encodePng(source));

      expect(
        () => AvatarProcessingService.processAvatarBytes(
          encoded,
          maxBase64Length: 16,
        ),
        throwsA(isA<AvatarTooLargeException>()),
      );
    });
  });
}
