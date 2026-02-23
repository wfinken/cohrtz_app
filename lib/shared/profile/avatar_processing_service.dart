import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'profile_constants.dart';

class AvatarProcessResult {
  const AvatarProcessResult({
    required this.base64Data,
    required this.encodedBytes,
    required this.quality,
  });

  final String base64Data;
  final int encodedBytes;
  final int quality;
}

class AvatarTooLargeException implements Exception {
  const AvatarTooLargeException(this.maxBase64Length);

  final int maxBase64Length;

  @override
  String toString() =>
      'AvatarTooLargeException: Could not compress under $maxBase64Length base64 chars';
}

class AvatarDecodeException implements Exception {
  const AvatarDecodeException();

  @override
  String toString() => 'AvatarDecodeException: Unable to decode image bytes';
}

class AvatarProcessingService {
  static Uint8List prepareBytesForCropping(
    Uint8List inputBytes, {
    int maxInputPixels = kAvatarCropMaxInputPixels,
    int reencodeThresholdBytes = kAvatarCropReencodeThresholdBytes,
    int outputQuality = kAvatarCropOutputJpegQuality,
  }) {
    if (inputBytes.isEmpty || inputBytes.length < reencodeThresholdBytes) {
      return inputBytes;
    }

    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw const AvatarDecodeException();
    }

    final longestEdge = math.max(decoded.width, decoded.height);
    if (longestEdge <= maxInputPixels) {
      return inputBytes;
    }

    final scale = maxInputPixels / longestEdge;
    final resized = img.copyResize(
      decoded,
      width: math.max(1, (decoded.width * scale).round()),
      height: math.max(1, (decoded.height * scale).round()),
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(img.encodeJpg(resized, quality: outputQuality));
  }

  static AvatarProcessResult processAvatarBytes(
    Uint8List inputBytes, {
    int targetPixels = kAvatarTargetPixels,
    int maxBase64Length = kAvatarMaxBase64Length,
  }) {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw const AvatarDecodeException();
    }

    final normalized = img.copyResizeCropSquare(decoded, size: targetPixels);

    for (var quality = 88; quality >= 40; quality -= 8) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(normalized, quality: quality),
      );
      final base64Data = base64Encode(encoded);
      if (base64Data.length <= maxBase64Length) {
        return AvatarProcessResult(
          base64Data: base64Data,
          encodedBytes: encoded.length,
          quality: quality,
        );
      }
    }

    throw AvatarTooLargeException(maxBase64Length);
  }
}
