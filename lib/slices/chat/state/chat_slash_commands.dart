class ChatSlashCommandResult {
  final bool handled;
  final String? messageContent;
  final String? moderationAction;
  final String? moderationTargetHandle;
  final String moderationReason;
  final String? presenceState;
  final String? threadName;
  final String? feedback;

  const ChatSlashCommandResult({
    required this.handled,
    this.messageContent,
    this.moderationAction,
    this.moderationTargetHandle,
    this.moderationReason = '',
    this.presenceState,
    this.threadName,
    this.feedback,
  });

  static const ChatSlashCommandResult passthrough = ChatSlashCommandResult(
    handled: false,
  );
}

class ChatSlashCommandParser {
  const ChatSlashCommandParser();

  ChatSlashCommandResult parse(String rawInput) {
    final text = rawInput.trim();
    if (!text.startsWith('/')) return ChatSlashCommandResult.passthrough;
    final parts = text.split(RegExp(r'\s+'));
    if (parts.isEmpty) return ChatSlashCommandResult.passthrough;
    final command = parts.first.toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : const <String>[];

    switch (command) {
      case '/me':
        if (args.isEmpty) {
          return const ChatSlashCommandResult(
            handled: true,
            feedback: 'Usage: /me <action>',
          );
        }
        return ChatSlashCommandResult(
          handled: true,
          messageContent: '*${args.join(' ')}*',
        );
      case '/shrug':
        if (args.isEmpty) {
          return const ChatSlashCommandResult(
            handled: true,
            feedback: 'Usage: /shrug <text>',
          );
        }
        return ChatSlashCommandResult(
          handled: true,
          messageContent: '${args.join(' ')} (shrug)',
        );
      case '/thread':
        if (args.isEmpty) {
          return const ChatSlashCommandResult(
            handled: true,
            feedback: 'Usage: /thread <name>',
          );
        }
        return ChatSlashCommandResult(
          handled: true,
          threadName: args.join(' '),
        );
      case '/mute':
      case '/ban':
      case '/timeout':
        if (args.isEmpty) {
          return ChatSlashCommandResult(
            handled: true,
            feedback: 'Usage: $command @user [reason]',
          );
        }
        final target = args.first;
        final reason = args.length > 1 ? args.sublist(1).join(' ') : '';
        return ChatSlashCommandResult(
          handled: true,
          moderationAction: command.substring(1),
          moderationTargetHandle: target,
          moderationReason: reason,
        );
      case '/presence':
        if (args.isEmpty) {
          return const ChatSlashCommandResult(
            handled: true,
            feedback: 'Usage: /presence online|idle|offline',
          );
        }
        final state = args.first.toLowerCase();
        if (state != 'online' && state != 'idle' && state != 'offline') {
          return const ChatSlashCommandResult(
            handled: true,
            feedback: 'Presence must be online, idle, or offline.',
          );
        }
        return ChatSlashCommandResult(handled: true, presenceState: state);
      default:
        return const ChatSlashCommandResult(
          handled: true,
          feedback: 'Unknown slash command.',
        );
    }
  }
}
