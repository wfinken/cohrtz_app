import 'package:flutter/material.dart';

class ChatMarkdownSpans {
  static final RegExp _inlineToken = RegExp(
    r'(\*\*[^*]+\*\*|__[^_]+__|~~[^~]+~~|\|\|[^|]+\|\||`[^`]+`|\*[^*]+\*)',
  );
  static final RegExp _mentionToken = RegExp(r'@([A-Za-z0-9_.\-]+)');

  const ChatMarkdownSpans();

  TextSpan build({
    required BuildContext context,
    required String text,
    bool isDeleted = false,
  }) {
    final theme = Theme.of(context);
    final baseStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 14,
      height: 1.25,
      decoration: isDeleted ? TextDecoration.lineThrough : null,
      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
    );
    final mentionStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    final spans = <InlineSpan>[];
    if (_isCodeBlock(text)) {
      spans.add(
        TextSpan(
          text: _stripCodeBlock(text),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      );
      return TextSpan(style: baseStyle, children: spans);
    }

    var cursor = 0;
    for (final match in _inlineToken.allMatches(text)) {
      if (match.start > cursor) {
        _appendMentions(
          spans: spans,
          text: text.substring(cursor, match.start),
          baseStyle: baseStyle,
          mentionStyle: mentionStyle,
        );
      }
      final token = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: _tokenContent(token),
          style: _tokenStyle(baseStyle, token, theme),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      _appendMentions(
        spans: spans,
        text: text.substring(cursor),
        baseStyle: baseStyle,
        mentionStyle: mentionStyle,
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  bool _isCodeBlock(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith('```') &&
        trimmed.endsWith('```') &&
        trimmed.length >= 6;
  }

  String _stripCodeBlock(String text) {
    final trimmed = text.trim();
    return trimmed.substring(3, trimmed.length - 3).trim();
  }

  TextStyle _tokenStyle(TextStyle base, String token, ThemeData theme) {
    if (token.startsWith('**') && token.endsWith('**')) {
      return base.copyWith(fontWeight: FontWeight.bold);
    }
    if (token.startsWith('__') && token.endsWith('__')) {
      return base.copyWith(decoration: TextDecoration.underline);
    }
    if (token.startsWith('~~') && token.endsWith('~~')) {
      return base.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (token.startsWith('||') && token.endsWith('||')) {
      return base.copyWith(
        color: theme.colorScheme.surfaceContainerHighest,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      );
    }
    if (token.startsWith('`') && token.endsWith('`')) {
      return base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      );
    }
    if (token.startsWith('*') && token.endsWith('*')) {
      return base.copyWith(fontStyle: FontStyle.italic);
    }
    return base;
  }

  String _tokenContent(String token) {
    if (token.length < 2) return token;
    if ((token.startsWith('**') && token.endsWith('**')) ||
        (token.startsWith('__') && token.endsWith('__')) ||
        (token.startsWith('~~') && token.endsWith('~~')) ||
        (token.startsWith('||') && token.endsWith('||'))) {
      return token.substring(2, token.length - 2);
    }
    if ((token.startsWith('`') && token.endsWith('`')) ||
        (token.startsWith('*') && token.endsWith('*'))) {
      return token.substring(1, token.length - 1);
    }
    return token;
  }

  void _appendMentions({
    required List<InlineSpan> spans,
    required String text,
    required TextStyle baseStyle,
    required TextStyle mentionStyle,
  }) {
    var cursor = 0;
    for (final match in _mentionToken.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: match.group(0), style: mentionStyle));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
  }
}
