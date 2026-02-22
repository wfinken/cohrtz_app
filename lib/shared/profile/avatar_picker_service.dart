import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'avatar_processing_service.dart';

class AvatarPickerService {
  static Future<AvatarProcessResult?> pickCropAndProcessAvatar(
    BuildContext context,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final bytes = picked.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    if (!context.mounted) {
      return null;
    }

    final croppedBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AvatarCropDialog(imageBytes: bytes),
    );
    if (croppedBytes == null || croppedBytes.isEmpty) {
      return null;
    }

    return AvatarProcessingService.processAvatarBytes(croppedBytes);
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final CropController _cropController = CropController();
  bool _cropping = false;

  Uint8List? _extractCroppedBytes(dynamic result) {
    if (result is Uint8List) {
      return result;
    }

    try {
      final dynamic croppedImage = result.croppedImage;
      if (croppedImage is Uint8List) {
        return croppedImage;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  void _onCropped(dynamic result) {
    final cropped = _extractCroppedBytes(result);
    if (!mounted) return;
    if (cropped == null || cropped.isEmpty) {
      setState(() => _cropping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not crop image. Try another one.')),
      );
      return;
    }
    Navigator.of(context).pop(cropped);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crop Avatar',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'This preview matches the profile avatar shown to others.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  onCropped: _onCropped,
                  withCircleUi: true,
                  aspectRatio: 1,
                  interactive: true,
                  cornerDotBuilder: (size, edgeAlignment) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _cropping
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _cropping
                      ? null
                      : () {
                          setState(() => _cropping = true);
                          _cropController.crop();
                        },
                  child: _cropping
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Use This Avatar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
