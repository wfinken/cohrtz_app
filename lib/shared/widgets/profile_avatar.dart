import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.displayName,
    this.avatarBase64 = '',
    this.size = 40,
    this.fallbackIcon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.isOnline,
    this.showOnlineIndicator = false,
  });

  final String displayName;
  final String avatarBase64;
  final double size;
  final IconData? fallbackIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final bool? isOnline;
  final bool showOnlineIndicator;

  static final LinkedHashMap<String, MemoryImage> _imageCache =
      LinkedHashMap<String, MemoryImage>();
  static const int _imageCacheLimit = 120;

  ImageProvider<Object>? _resolveImageProvider() {
    final trimmed = avatarBase64.trim();
    if (trimmed.isEmpty) return null;

    final cached = _imageCache.remove(trimmed);
    if (cached != null) {
      _imageCache[trimmed] = cached;
      return cached;
    }

    try {
      final decoded = MemoryImage(base64Decode(trimmed));
      _imageCache[trimmed] = decoded;
      if (_imageCache.length > _imageCacheLimit) {
        _imageCache.remove(_imageCache.keys.first);
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) {
      final first = list.first;
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageProvider = _resolveImageProvider();
    final defaultBackground =
        backgroundColor ?? theme.colorScheme.primaryContainer;
    final defaultForeground =
        foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: defaultBackground,
      foregroundColor: defaultForeground,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? (fallbackIcon != null
                ? Icon(fallbackIcon, size: size * 0.52)
                : Text(
                    _initials(displayName),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.34,
                    ),
                  ))
          : null,
    );

    final bordered = borderWidth > 0
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor ?? theme.colorScheme.surface,
                width: borderWidth,
              ),
            ),
            child: avatar,
          )
        : SizedBox(width: size, height: size, child: avatar);

    if (!showOnlineIndicator) {
      return bordered;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bordered,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isOnline ?? false)
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
