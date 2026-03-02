import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/slices/chat/state/chat_slash_commands.dart';

void main() {
  group('ChatSlashCommandParser', () {
    const parser = ChatSlashCommandParser();

    test('passes through plain messages', () {
      final result = parser.parse('hello world');
      expect(result.handled, isFalse);
    });

    test('parses /me command', () {
      final result = parser.parse('/me testing');
      expect(result.handled, isTrue);
      expect(result.messageContent, '*testing*');
    });

    test('parses moderation commands', () {
      final result = parser.parse('/ban @alice too noisy');
      expect(result.handled, isTrue);
      expect(result.moderationAction, 'ban');
      expect(result.moderationTargetHandle, '@alice');
      expect(result.moderationReason, 'too noisy');
    });

    test('validates presence command', () {
      final valid = parser.parse('/presence idle');
      expect(valid.presenceState, 'idle');

      final invalid = parser.parse('/presence hidden');
      expect(invalid.handled, isTrue);
      expect(invalid.feedback, isNotEmpty);
    });
  });
}
