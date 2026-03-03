import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/shared/theme/tokens/dialog_button_styles.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import '../controllers/chat_read_receipt_controller.dart';

import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/skeleton_loader.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/role_providers.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/permissions_feature/ui/widgets/visibility_group_selector.dart';
import 'package:cohortz/slices/chat/state/chat_mention_parser.dart';
import 'package:cohortz/slices/chat/state/chat_slash_commands.dart';
import 'package:cohortz/slices/chat/ui/utils/chat_markdown_spans.dart';

import '../../../../shared/theme/tokens/app_shape_tokens.dart';

enum _ThreadAction { createChannel, startDm }

enum _SelectedThreadAction { editChannel, deleteChannel, leaveDm }

enum _MessageAction {
  reply,
  edit,
  delete,
  pinToggle,
  addReaction,
  startThread,
  report,
  timeout,
  mute,
  ban,
}

enum _ComposerSuggestionKind { mention, thread }

class _ReactionOption {
  final String id;
  final IconData icon;
  final String label;

  const _ReactionOption({
    required this.id,
    required this.icon,
    required this.label,
  });
}

class _ComposerSuggestion {
  final _ComposerSuggestionKind kind;
  final String id;
  final String label;
  final String insertText;
  final String subtitle;
  final IconData icon;

  const _ComposerSuggestion({
    required this.kind,
    required this.id,
    required this.label,
    required this.insertText,
    required this.subtitle,
    required this.icon,
  });
}

class ChatWidget extends ConsumerStatefulWidget {
  final bool isFullPage;
  final bool isAccordion;
  final VoidCallback? onToggleAccordion;
  final bool isOpen;

  const ChatWidget({
    super.key,
    this.isFullPage = false,
    this.isAccordion = false,
    this.onToggleAccordion,
    this.isOpen = false,
  });

  @override
  ConsumerState<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends ConsumerState<ChatWidget> {
  static const _reactionOptions = <_ReactionOption>[
    _ReactionOption(
      id: 'thumb_up',
      icon: Icons.thumb_up_alt_rounded,
      label: 'Thumbs up',
    ),
    _ReactionOption(id: 'heart', icon: Icons.favorite_rounded, label: 'Heart'),
    _ReactionOption(
      id: 'fire',
      icon: Icons.local_fire_department_rounded,
      label: 'Fire',
    ),
    _ReactionOption(id: 'eyes', icon: Icons.visibility_rounded, label: 'Eyes'),
    _ReactionOption(
      id: 'rocket',
      icon: Icons.rocket_launch_rounded,
      label: 'Rocket',
    ),
    _ReactionOption(
      id: 'smile',
      icon: Icons.sentiment_very_satisfied_rounded,
      label: 'Smile',
    ),
  ];

  final _controller = TextEditingController();
  final _composerFocusNode = FocusNode();
  final _mentionParser = const ChatMentionParser();
  final _slashParser = const ChatSlashCommandParser();
  final _markdownSpans = const ChatMarkdownSpans();
  String _selectedThreadId = ChatThread.generalId;
  String? _replyToMessageId;
  String? _editingMessageId;
  String? _lastOwnMessageId;
  String? _hoveredMessageId;
  int? _composerSuggestionStart;
  List<_ComposerSuggestion> _composerSuggestions = const [];
  int _composerSuggestionIndex = 0;
  String _presenceState = 'online';
  Timer? _typingTimer;
  Timer? _presenceHeartbeat;
  late final ChatReadReceiptController _readReceiptController;
  ProviderSubscription<AsyncValue<List<ChatMessage>>>? _readReceiptSubscription;
  String? _readReceiptSubscriptionThreadId;
  String? _readReceiptGroupId;

  @override
  void initState() {
    super.initState();
    _readReceiptController = ChatReadReceiptController(
      ref.read(localDashboardStorageProvider),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presenceHeartbeat?.cancel();
    _readReceiptSubscription?.close();
    _readReceiptController.dispose();
    _composerFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatClockProvider);
    final repo = ref.watch(dashboardRepositoryProvider);
    final profilesAsync = ref.watch(userProfilesProvider);
    final rolesAsync = ref.watch(rolesProvider);
    final threadsAsync = ref.watch(chatThreadsStreamProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final syncIdentity = ref.watch(
      syncServiceProvider.select((s) => s.identity),
    );
    final myId = syncIdentity ?? '';

    final canEditChat = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editChat),
      orElse: () => false,
    );
    final canManageChat = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageChat),
      orElse: () => false,
    );
    final canCreateChannels =
        (widget.isFullPage || widget.isAccordion) &&
        permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.createChatRooms),
          orElse: () => false,
        );
    final canEditChannels = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editChatRooms),
      orElse: () => false,
    );
    final canDeleteChannels = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.deleteChatRooms),
      orElse: () => false,
    );
    final canStartDms =
        syncIdentity != null &&
        syncIdentity.isNotEmpty &&
        (widget.isFullPage || widget.isAccordion) &&
        permissionsAsync.maybeWhen(
          data: (permissions) => PermissionUtils.has(
            permissions,
            PermissionFlags.startPrivateChats,
          ),
          orElse: () => false,
        );
    final canLeaveDms = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.leavePrivateChats),
      orElse: () => false,
    );
    final canMentionEveryone = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.mentionEveryone),
      orElse: () => false,
    );
    final canManageMembers = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageMembers),
      orElse: () => false,
    );

    return threadsAsync.when(
      data: (threads) {
        final profiles = profilesAsync.value ?? const <UserProfile>[];
        final roles = rolesAsync.value ?? const <Role>[];
        final logicalGroups = ref.watch(logicalGroupsProvider);
        final userMap = {for (final p in profiles) p.id: p.displayName};
        final visibleThreads = _visibleThreads(threads, myId);
        final selectedThreadId = _effectiveThreadId(visibleThreads);
        final selectedThread = visibleThreads.firstWhere(
          (thread) => thread.id == selectedThreadId,
        );
        _syncReadReceiptSubscription(
          threadId: selectedThreadId,
          groupId: repo.currentRoomName,
        );

        final messagesAsync = ref.watch(
          threadMessagesStreamProvider(selectedThreadId),
        );
        final typingAsync = ref.watch(typingStatesProvider(selectedThreadId));
        _syncPresenceHeartbeat(myId: myId);

        return LayoutBuilder(
          builder: (context, constraints) {
            final showDrawer =
                !widget.isAccordion &&
                widget.isFullPage &&
                constraints.maxWidth >= 900;
            final showSelector =
                !widget.isAccordion && (widget.isFullPage && !showDrawer);

            return Column(
              children: [
                if (showSelector)
                  _buildSelectorRow(
                    threads: visibleThreads,
                    selectedThreadId: selectedThreadId,
                    userMap: userMap,
                    myId: myId,
                    canCreateChannels: canCreateChannels,
                    canStartDms: canStartDms,
                    onAction: (action) => _handleThreadAction(
                      action: action,
                      profiles: profiles,
                      myId: syncIdentity ?? '',
                      canCreateChannels: canCreateChannels,
                      canStartDms: canStartDms,
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      if (showDrawer)
                        SizedBox(
                          width: 280,
                          child: _buildThreadDrawer(
                            threads: visibleThreads,
                            selectedThreadId: selectedThreadId,
                            userMap: userMap,
                            myId: myId,
                            canCreateChannels: canCreateChannels,
                            canStartDms: canStartDms,
                            onAction: (action) => _handleThreadAction(
                              action: action,
                              profiles: profiles,
                              myId: syncIdentity ?? '',
                              canCreateChannels: canCreateChannels,
                              canStartDms: canStartDms,
                            ),
                          ),
                        ),
                      if (showDrawer)
                        VerticalDivider(
                          width: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                      Expanded(
                        child: _buildConversationPane(
                          repo: repo,
                          messagesAsync: messagesAsync,
                          threads: visibleThreads,
                          selectedThreadId: selectedThreadId,
                          selectedThread: selectedThread,
                          userMap: userMap,
                          myId: myId,
                          profiles: profiles,
                          roles: roles,
                          logicalGroups: logicalGroups,
                          canEditChat: canEditChat,
                          canEditChannels: canEditChannels || canManageChat,
                          canDeleteChannels: canDeleteChannels || canManageChat,
                          canLeaveDms: canLeaveDms || canManageChat,
                          canMentionEveryone: canMentionEveryone,
                          canManageMembers: canManageMembers || canManageChat,
                          typingAsync: typingAsync,
                          showHeader: widget.isFullPage && !widget.isAccordion,
                          showInlineThreadPicker:
                              (!widget.isFullPage && !widget.isAccordion) ||
                              widget.isAccordion,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const ChatLoadingSkeleton(),
      error: (e, s) => Center(
        child: Text(
          'Could not load chats',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  List<ChatThread> _visibleThreads(List<ChatThread> threads, String myId) {
    final now = DateTime.now();
    if (myId.isEmpty) {
      return threads
          .where(
            (thread) =>
                thread.kind == ChatThread.channelKind ||
                thread.kind == ChatThread.subthreadKind,
          )
          .where(
            (thread) =>
                thread.id == ChatThread.generalId ||
                thread.expiresAt == null ||
                now.isBefore(thread.expiresAt!),
          )
          .toList();
    }
    final visible = threads.where((thread) {
      final isActive =
          thread.id == ChatThread.generalId ||
          thread.expiresAt == null ||
          now.isBefore(thread.expiresAt!);
      if (!isActive) return false;
      if (thread.isChannel) return true;
      if (thread.isSubthread) {
        if (thread.memberIds.isEmpty) return true;
        return thread.memberIds.contains(myId);
      }
      return thread.participantIds.contains(myId);
    }).toList();
    if (!visible.any((thread) => thread.id == ChatThread.generalId)) {
      visible.insert(
        0,
        ChatThread(
          id: ChatThread.generalId,
          kind: ChatThread.channelKind,
          name: 'general',
          createdBy: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    return visible;
  }

  String _effectiveThreadId(List<ChatThread> threads) {
    if (threads.isEmpty) return ChatThread.generalId;
    final exists = threads.any((thread) => thread.id == _selectedThreadId);
    return exists ? _selectedThreadId : threads.first.id;
  }

  void _syncReadReceiptSubscription({
    required String threadId,
    required String? groupId,
  }) {
    final group = groupId ?? '';
    final bool isVisible =
        widget.isFullPage ||
        (widget.isAccordion && widget.isOpen) ||
        (!widget.isFullPage && !widget.isAccordion && widget.isOpen);

    if (!isVisible || group.isEmpty) {
      _readReceiptSubscription?.close();
      _readReceiptSubscription = null;
      _readReceiptSubscriptionThreadId = null;
      _readReceiptGroupId = null;
      return;
    }

    if (_readReceiptSubscription != null &&
        _readReceiptSubscriptionThreadId == threadId &&
        _readReceiptGroupId == group) {
      return;
    }

    _readReceiptSubscription?.close();
    _readReceiptSubscriptionThreadId = threadId;
    _readReceiptGroupId = group;
    _readReceiptSubscription = ref.listenManual(
      threadMessagesStreamProvider(threadId),
      (previous, next) {
        if (next.hasValue) {
          _markThreadRead(threadId, group);
        }
      },
    );

    // Ensure we clear unread state when chat becomes visible even if the
    // thread stream does not emit a new event after subscribing.
    _markThreadRead(threadId, group);
  }

  void _markThreadRead(String threadId, String groupId) {
    if (groupId.isEmpty) return;

    final bool isVisible =
        widget.isFullPage ||
        (widget.isAccordion && widget.isOpen) ||
        (!widget.isFullPage && !widget.isAccordion && widget.isOpen);

    if (!isVisible) return;

    final now = ref.read(hybridTimeServiceProvider).getAdjustedTimeUtcMs();
    final latestVisibleMessageMs = ref
        .read(threadMessagesStreamProvider(threadId))
        .maybeWhen(
          data: (messages) => messages.fold<int>(
            0,
            (latest, msg) => msg.timestamp.millisecondsSinceEpoch > latest
                ? msg.timestamp.millisecondsSinceEpoch
                : latest,
          ),
          orElse: () => 0,
        );
    final readTimestampMs = latestVisibleMessageMs > now
        ? latestVisibleMessageMs
        : now;
    _readReceiptController.markVisible(
      groupId: groupId,
      threadId: threadId,
      timestampMs: readTimestampMs,
    );
  }

  void _syncPresenceHeartbeat({required String myId}) {
    final bool isVisible =
        widget.isFullPage ||
        (widget.isAccordion && widget.isOpen) ||
        (!widget.isFullPage && !widget.isAccordion && widget.isOpen);
    if (!isVisible || myId.isEmpty) {
      _presenceHeartbeat?.cancel();
      _presenceHeartbeat = null;
      return;
    }

    Future<void> writePresence() async {
      await ref
          .read(dashboardRepositoryProvider)
          .touchPresence(userId: myId, state: _presenceState);
    }

    if (_presenceHeartbeat == null) {
      _presenceHeartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        writePresence();
      });
      writePresence();
    }
  }

  Widget _buildSelectorRow({
    required List<ChatThread> threads,
    required String selectedThreadId,
    required Map<String, String> userMap,
    required String myId,
    required bool canCreateChannels,
    required bool canStartDms,
    required Future<void> Function(_ThreadAction action) onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: context.appBorderRadius(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    style: Theme.of(context).textTheme.bodyMedium,

                    dropdownColor: Theme.of(context).colorScheme.surface,
                    iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                    iconDisabledColor: Theme.of(context).colorScheme.onSurface,
                    focusColor: Theme.of(context).colorScheme.surface,
                    isExpanded: true,
                    value: selectedThreadId,
                    items: threads
                        .map(
                          (thread) => DropdownMenuItem<String>(
                            value: thread.id,
                            child: Text(
                              _threadTitle(thread, userMap, myId),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (nextId) {
                      if (nextId == null) return;
                      setState(() => _selectedThreadId = nextId);
                    },
                  ),
                ),
              ),
            ),
          ),
          if (canCreateChannels || canStartDms) ...[
            const SizedBox(width: 8),
            PopupMenuButton<_ThreadAction>(
              tooltip: 'Create chat',
              onSelected: onAction,
              itemBuilder: (context) => [
                if (canCreateChannels)
                  const PopupMenuItem(
                    value: _ThreadAction.createChannel,
                    child: Text('Create channel'),
                  ),
                if (canStartDms)
                  const PopupMenuItem(
                    value: _ThreadAction.startDm,
                    child: Text('Start private chat'),
                  ),
              ],
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThreadDrawer({
    required List<ChatThread> threads,
    required String selectedThreadId,
    required Map<String, String> userMap,
    required String myId,
    required bool canCreateChannels,
    required bool canStartDms,
    required Future<void> Function(_ThreadAction action) onAction,
  }) {
    final channels = threads.where((thread) => thread.isChannel).toList();
    final subthreads = threads.where((thread) => thread.isSubthread).toList();
    final dms = threads.where((thread) => thread.isDm).toList();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThreadSectionHeader(
            title: 'Channels',
            onCreate: canCreateChannels
                ? () => onAction(_ThreadAction.createChannel)
                : null,
          ),
          Expanded(
            child: ListView(
              children: [
                ...channels.map(
                  (thread) => _buildThreadTile(
                    thread: thread,
                    selectedThreadId: selectedThreadId,
                    title: _threadTitle(thread, userMap, myId),
                    subtitle: _threadSubtitle(thread),
                    icon: Icons.tag,
                  ),
                ),
                if (subthreads.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildThreadSectionHeader(title: 'Threads'),
                  ...subthreads.map(
                    (thread) => _buildThreadTile(
                      thread: thread,
                      selectedThreadId: selectedThreadId,
                      title: _threadTitle(thread, userMap, myId),
                      subtitle: _threadSubtitle(thread),
                      icon: Icons.forum_outlined,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _buildThreadSectionHeader(
                  title: 'Private Chats',
                  onCreate: canStartDms
                      ? () => onAction(_ThreadAction.startDm)
                      : null,
                ),
                ...dms.map(
                  (thread) => _buildThreadTile(
                    thread: thread,
                    selectedThreadId: selectedThreadId,
                    title: _threadTitle(thread, userMap, myId),
                    subtitle: 'Private',
                    icon: Icons.lock_outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadSectionHeader({
    required String title,
    VoidCallback? onCreate,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onCreate != null)
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              tooltip: title == 'Channels'
                  ? 'Create channel'
                  : 'Start private chat',
              onPressed: onCreate,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildThreadTile({
    required ChatThread thread,
    required String selectedThreadId,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = selectedThreadId == thread.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        hoverColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: context.appBorderRadius(10),
        ),
        leading: Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onPrimaryFixedVariant,
          ),
        ),
        onTap: () => setState(() => _selectedThreadId = thread.id),
      ),
    );
  }

  Widget _buildConversationPane({
    required DashboardRepository repo,
    required AsyncValue<List<ChatMessage>> messagesAsync,
    required List<ChatThread> threads,
    required String selectedThreadId,
    required ChatThread selectedThread,
    required Map<String, String> userMap,
    required String myId,
    required List<UserProfile> profiles,
    required List<Role> roles,
    required List<LogicalGroup> logicalGroups,
    required bool canEditChat,
    required bool canEditChannels,
    required bool canDeleteChannels,
    required bool canLeaveDms,
    required bool canMentionEveryone,
    required bool canManageMembers,
    required AsyncValue<List<ChatTypingState>> typingAsync,
    required bool showHeader,
    required bool showInlineThreadPicker,
  }) {
    final isExpired =
        selectedThread.expiresAt != null &&
        DateTime.now().isAfter(selectedThread.expiresAt!);
    final canSend = canEditChat && !isExpired;
    final threadActions = _buildThreadActions(
      selectedThread: selectedThread,
      myId: myId,
      canEditChannels: canEditChannels,
      canDeleteChannels: canDeleteChannels,
      canLeaveDms: canLeaveDms,
    );

    return Column(
      children: [
        if (showHeader)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 12),
              child: Row(
                children: [
                  Icon(
                    selectedThread.isDm ? Icons.lock_outline : Icons.tag,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: selectedThread.isDm
                                ? _threadTitle(selectedThread, userMap, myId)
                                : _threadTitle(selectedThread, userMap, myId),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: _threadSubtitle(selectedThread),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.push_pin_outlined, size: 20),
                    tooltip: 'Pinned messages',
                    onPressed: () => _showPinnedMessagesDialog(
                      messagesAsync.value ?? const <ChatMessage>[],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    tooltip: 'Search messages',
                    onPressed: () => _showSearchDialog(
                      repo: repo,
                      userMap: userMap,
                      currentThreadId: selectedThread.id,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.rule_folder_outlined, size: 20),
                    tooltip: 'Moderation log',
                    onPressed: () => _showModerationLogDialog(
                      threadId: selectedThread.id,
                      userMap: userMap,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    tooltip: 'Clear chat history',
                    onPressed: () => _clearChatHistory(repo, selectedThread),
                  ),
                  if (threadActions.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<_SelectedThreadAction>(
                      tooltip: 'Chat options',
                      onSelected: (action) => _handleSelectedThreadAction(
                        action: action,
                        thread: selectedThread,
                        myId: myId,
                      ),
                      itemBuilder: (context) => threadActions,
                      icon: const Icon(Icons.more_horiz, size: 18),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Expanded(
          child: messagesAsync.when(
            data: (messages) => _buildMessagesList(
              repo: repo,
              messages: messages,
              userMap: userMap,
              myId: myId,
              canManageMembers: canManageMembers,
              canEditChat: canEditChat,
              selectedThread: selectedThread,
            ),
            loading: () => const ChatLoadingSkeleton(),
            error: (e, s) => Center(
              child: Text(
                'Unable to load messages',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
        _buildTypingIndicator(
          typingAsync: typingAsync,
          userMap: userMap,
          myId: myId,
        ),
        _buildComposer(
          canSend: canSend,
          isExpired: isExpired,
          selectedThreadId: selectedThread.id,
          myId: myId,
          threads: threads,
          profiles: profiles,
          roles: roles,
          logicalGroups: logicalGroups,
          canMentionEveryone: canMentionEveryone,
          canManageMembers: canManageMembers,
          leading: showInlineThreadPicker
              ? _buildInlineThreadPicker(
                  threads: threads,
                  selectedThreadId: selectedThreadId,
                  userMap: userMap,
                  myId: myId,
                )
              : null,
          onSend: (text) => _sendMessage(
            repo,
            text,
            threadId: selectedThread.id,
            myId: myId,
            profiles: profiles,
            roles: roles,
            logicalGroups: logicalGroups,
            canMentionEveryone: canMentionEveryone,
            canManageMembers: canManageMembers,
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList({
    required DashboardRepository repo,
    required List<ChatMessage> messages,
    required Map<String, String> userMap,
    required String myId,
    required bool canManageMembers,
    required bool canEditChat,
    required ChatThread selectedThread,
  }) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }

    final messageById = <String, ChatMessage>{
      for (final m in messages) m.id: m,
    };
    const timestampWidth = 42.0;
    const timestampGap = 8.0;
    const usernameMaxWidth = 132.0;
    final reversedMessages = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      itemCount: reversedMessages.length,
      itemBuilder: (context, index) {
        final msg = reversedMessages[index];
        final isMe = msg.senderId == myId;
        final displayName = isMe ? 'You' : (userMap[msg.senderId] ?? 'Member');
        final timeText = _formatMessageTime(msg.timestamp);
        final replyTo = msg.replyToMessageId == null
            ? null
            : messageById[msg.replyToMessageId!];
        final nameColor = _usernameColor(
          senderId: msg.senderId,
          isMe: isMe,
          theme: Theme.of(context),
        );
        final canDelete = isMe || canManageMembers;
        final canEdit = isMe && !msg.isDeleted;
        final canPin = canManageMembers || canEditChat;
        final canModerate = canManageMembers && !isMe;
        final supportsHoverActions =
            Theme.of(context).platform != TargetPlatform.android &&
            Theme.of(context).platform != TargetPlatform.iOS;

        final isHovered = _hoveredMessageId == msg.id;
        return MouseRegion(
          onEnter: (_) {
            if (!supportsHoverActions) return;
            if (_hoveredMessageId == msg.id) return;
            setState(() => _hoveredMessageId = msg.id);
          },
          onExit: (_) {
            if (!supportsHoverActions) return;
            if (_hoveredMessageId != msg.id) return;
            setState(() => _hoveredMessageId = null);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replyTo != null)
                      Text(
                        'Replying to ${userMap[replyTo.senderId] ?? 'Member'}: ${replyTo.content}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Row(
                      spacing: timestampGap,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                        Expanded(
                          child: Row(
                            spacing: timestampGap,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: usernameMaxWidth,
                                ),
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: nameColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      _markdownSpans.build(
                                        context: context,
                                        text: msg.isDeleted
                                            ? '[message deleted]'
                                            : msg.content,
                                        isDeleted: msg.isDeleted,
                                      ),
                                      if (msg.editedAt != null)
                                        TextSpan(
                                          text: ' (edited)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      if (msg.isPinned)
                                        TextSpan(
                                          text: ' • pinned',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (msg.reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: timestampWidth + timestampGap,
                          top: 4,
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: msg.reactions.entries.map((entry) {
                            final reacted = entry.value.contains(myId);
                            final icon = _reactionIcon(entry.key);
                            return InkWell(
                              onTap: () => repo.toggleReaction(
                                messageId: msg.id,
                                emoji: entry.key,
                                userId: myId,
                              ),
                              borderRadius: context.appBorderRadius(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: reacted
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: context.appBorderRadius(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (icon != null)
                                      Icon(
                                        icon,
                                        size: 14,
                                        color: reacted
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      )
                                    else
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: reacted
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${entry.value.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: reacted
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: -18,
                child: supportsHoverActions
                    ? AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: isHovered ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !isHovered,
                          child: _buildMessageActionToolbar(
                            message: msg,
                            selectedThread: selectedThread,
                            myId: myId,
                            canEdit: canEdit,
                            canDelete: canDelete,
                            canPin: canPin,
                            canModerate: canModerate,
                            userMap: userMap,
                          ),
                        ),
                      )
                    : _buildMessageOverflowMenu(
                        message: msg,
                        selectedThread: selectedThread,
                        myId: myId,
                        canEdit: canEdit,
                        canDelete: canDelete,
                        canPin: canPin,
                        canModerate: canModerate,
                        userMap: userMap,
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageOverflowMenu({
    required ChatMessage message,
    required ChatThread selectedThread,
    required String myId,
    required bool canEdit,
    required bool canDelete,
    required bool canPin,
    required bool canModerate,
    required Map<String, String> userMap,
    required double iconSize,
    required EdgeInsetsGeometry padding,
    required double splashRadius,
  }) {
    final theme = Theme.of(context);
    return PopupMenuButton<_MessageAction>(
      tooltip: 'More actions',
      onSelected: (action) => _handleMessageAction(
        action: action,
        message: message,
        thread: selectedThread,
        myId: myId,
        canEdit: canEdit,
        canDelete: canDelete,
        canPin: canPin,
        canModerate: canModerate,
        userMap: userMap,
      ),
      itemBuilder: (context) => _buildMessageActionMenuItems(
        message: message,
        selectedThread: selectedThread,
        canEdit: canEdit,
        canDelete: canDelete,
        canPin: canPin,
        canModerate: canModerate,
      ),
      icon: Icon(
        Icons.more_horiz,
        size: iconSize,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      padding: padding,
      splashRadius: splashRadius,
    );
  }

  Widget _buildMessageActionToolbar({
    required ChatMessage message,
    required ChatThread selectedThread,
    required String myId,
    required bool canEdit,
    required bool canDelete,
    required bool canPin,
    required bool canModerate,
    required Map<String, String> userMap,
  }) {
    final theme = Theme.of(context);
    final quickActions = <_MessageAction>[
      _MessageAction.reply,
      _MessageAction.addReaction,
      if (!selectedThread.isDm) _MessageAction.startThread,
      if (canPin) _MessageAction.pinToggle,
      if (canEdit) _MessageAction.edit,
      if (canDelete) _MessageAction.delete,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.98),
        border: Border.all(color: theme.dividerColor),
        borderRadius: context.appBorderRadius(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in quickActions)
            _buildMessageActionIconButton(
              icon: _messageActionIcon(action, message),
              tooltip: _messageActionLabel(action, message),
              onTap: () => _handleMessageAction(
                action: action,
                message: message,
                thread: selectedThread,
                myId: myId,
                canEdit: canEdit,
                canDelete: canDelete,
                canPin: canPin,
                canModerate: canModerate,
                userMap: userMap,
              ),
            ),
          _buildMessageOverflowMenu(
            message: message,
            selectedThread: selectedThread,
            myId: myId,
            canEdit: canEdit,
            canDelete: canDelete,
            canPin: canPin,
            canModerate: canModerate,
            userMap: userMap,
            iconSize: 16,
            padding: const EdgeInsets.all(2),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageActionIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: context.appBorderRadius(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  IconData _messageActionIcon(_MessageAction action, ChatMessage message) {
    switch (action) {
      case _MessageAction.reply:
        return Icons.reply_rounded;
      case _MessageAction.edit:
        return Icons.edit_outlined;
      case _MessageAction.delete:
        return Icons.delete_outline_rounded;
      case _MessageAction.pinToggle:
        return message.isPinned ? Icons.push_pin : Icons.push_pin_outlined;
      case _MessageAction.addReaction:
        return Icons.add_reaction_outlined;
      case _MessageAction.startThread:
        return Icons.forum_outlined;
      case _MessageAction.report:
        return Icons.flag_outlined;
      case _MessageAction.timeout:
        return Icons.timer_off_outlined;
      case _MessageAction.mute:
        return Icons.volume_off_outlined;
      case _MessageAction.ban:
        return Icons.block_outlined;
    }
  }

  String _messageActionLabel(_MessageAction action, ChatMessage message) {
    switch (action) {
      case _MessageAction.reply:
        return 'Reply';
      case _MessageAction.edit:
        return 'Edit';
      case _MessageAction.delete:
        return 'Delete';
      case _MessageAction.pinToggle:
        return message.isPinned ? 'Unpin' : 'Pin';
      case _MessageAction.addReaction:
        return 'Add reaction';
      case _MessageAction.startThread:
        return 'Start thread';
      case _MessageAction.report:
        return 'Report message';
      case _MessageAction.timeout:
        return 'Timeout user';
      case _MessageAction.mute:
        return 'Mute user';
      case _MessageAction.ban:
        return 'Ban user';
    }
  }

  List<PopupMenuEntry<_MessageAction>> _buildMessageActionMenuItems({
    required ChatMessage message,
    required ChatThread selectedThread,
    required bool canEdit,
    required bool canDelete,
    required bool canPin,
    required bool canModerate,
  }) {
    return [
      PopupMenuItem(
        value: _MessageAction.reply,
        child: Row(
          spacing: 8,
          children: [
            Icon(_messageActionIcon(_MessageAction.reply, message), size: 16),
            const Text('Reply'),
          ],
        ),
      ),
      if (canEdit)
        PopupMenuItem(
          value: _MessageAction.edit,
          child: Row(
            spacing: 8,
            children: [
              Icon(_messageActionIcon(_MessageAction.edit, message), size: 16),
              const Text('Edit'),
            ],
          ),
        ),
      if (canDelete)
        PopupMenuItem(
          value: _MessageAction.delete,
          child: Row(
            spacing: 8,
            children: [
              Icon(
                _messageActionIcon(_MessageAction.delete, message),
                size: 16,
              ),
              const Text('Delete'),
            ],
          ),
        ),
      if (canPin)
        PopupMenuItem(
          value: _MessageAction.pinToggle,
          child: Row(
            spacing: 8,
            children: [
              Icon(
                _messageActionIcon(_MessageAction.pinToggle, message),
                size: 16,
              ),
              Text(message.isPinned ? 'Unpin' : 'Pin'),
            ],
          ),
        ),
      PopupMenuItem(
        value: _MessageAction.addReaction,
        child: Row(
          spacing: 8,
          children: [
            Icon(
              _messageActionIcon(_MessageAction.addReaction, message),
              size: 16,
            ),
            const Text('Add reaction'),
          ],
        ),
      ),
      if (!selectedThread.isDm)
        PopupMenuItem(
          value: _MessageAction.startThread,
          child: Row(
            spacing: 8,
            children: [
              Icon(
                _messageActionIcon(_MessageAction.startThread, message),
                size: 16,
              ),
              const Text('Start thread'),
            ],
          ),
        ),
      PopupMenuItem(
        value: _MessageAction.report,
        child: Row(
          spacing: 8,
          children: [
            Icon(_messageActionIcon(_MessageAction.report, message), size: 16),
            const Text('Report message'),
          ],
        ),
      ),
      if (canModerate) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MessageAction.timeout,
          child: Row(
            spacing: 8,
            children: [
              Icon(
                _messageActionIcon(_MessageAction.timeout, message),
                size: 16,
              ),
              const Text('Timeout user'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MessageAction.mute,
          child: Row(
            spacing: 8,
            children: [
              Icon(_messageActionIcon(_MessageAction.mute, message), size: 16),
              const Text('Mute user'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MessageAction.ban,
          child: Row(
            spacing: 8,
            children: [
              Icon(_messageActionIcon(_MessageAction.ban, message), size: 16),
              const Text('Ban user'),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildTypingIndicator({
    required AsyncValue<List<ChatTypingState>> typingAsync,
    required Map<String, String> userMap,
    required String myId,
  }) {
    final typingUsers = typingAsync.maybeWhen(
      data: (states) => states.where((state) => state.userId != myId).toList(),
      orElse: () => const <ChatTypingState>[],
    );
    if (typingUsers.isEmpty) return const SizedBox.shrink();
    final typingText =
        '${typingUsers.map((state) => userMap[state.userId] ?? 'Member').join(', ')} typing...';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          typingText,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _handleMessageAction({
    required _MessageAction action,
    required ChatMessage message,
    required ChatThread thread,
    required String myId,
    required bool canEdit,
    required bool canDelete,
    required bool canPin,
    required bool canModerate,
    required Map<String, String> userMap,
  }) async {
    final repo = ref.read(dashboardRepositoryProvider);
    switch (action) {
      case _MessageAction.reply:
        setState(() => _replyToMessageId = message.id);
        _composerFocusNode.requestFocus();
        return;
      case _MessageAction.edit:
        if (!canEdit) return;
        setState(() {
          _editingMessageId = message.id;
          _controller.text = message.content;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
        _composerFocusNode.requestFocus();
        return;
      case _MessageAction.delete:
        if (!canDelete) return;
        await repo.softDeleteMessage(messageId: message.id, deletedBy: myId);
        return;
      case _MessageAction.pinToggle:
        if (!canPin) return;
        await repo.togglePin(
          messageId: message.id,
          pinned: !message.isPinned,
          actorId: myId,
        );
        return;
      case _MessageAction.addReaction:
        final emoji = await _showReactionPicker();
        if (emoji == null || emoji.isEmpty) return;
        await repo.toggleReaction(
          messageId: message.id,
          emoji: emoji,
          userId: myId,
        );
        return;
      case _MessageAction.startThread:
        final threadName = await _showThreadNameDialog();
        if (threadName == null) return;
        final created = await repo.createSubthreadFromMessage(
          parentMessageId: message.id,
          creatorId: myId,
          name: threadName,
        );
        if (!mounted) return;
        setState(() => _selectedThreadId = created.id);
        return;
      case _MessageAction.report:
        await _reportMessage(
          message: message,
          action: 'report',
          myId: myId,
          reason: 'user report',
        );
        return;
      case _MessageAction.timeout:
        if (!canModerate) return;
        await _reportMessage(
          message: message,
          action: 'timeout',
          myId: myId,
          reason: 'timeout via message action',
        );
        return;
      case _MessageAction.mute:
        if (!canModerate) return;
        await _reportMessage(
          message: message,
          action: 'mute',
          myId: myId,
          reason: 'mute via message action',
        );
        return;
      case _MessageAction.ban:
        if (!canModerate) return;
        await _reportMessage(
          message: message,
          action: 'ban',
          myId: myId,
          reason: 'ban via message action',
        );
        return;
    }
  }

  Future<String?> _showReactionPicker() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _reactionOptions
                .map(
                  (option) => ListTile(
                    leading: Icon(option.icon),
                    title: Text(option.label),
                    onTap: () => Navigator.pop(context, option.id),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  IconData? _reactionIcon(String key) {
    switch (key) {
      case 'thumb_up':
      case ':thumbsup:':
        return Icons.thumb_up_alt_rounded;
      case 'heart':
      case ':heart:':
        return Icons.favorite_rounded;
      case 'fire':
      case ':fire:':
        return Icons.local_fire_department_rounded;
      case 'eyes':
      case ':eyes:':
        return Icons.visibility_rounded;
      case 'rocket':
      case ':rocket:':
        return Icons.rocket_launch_rounded;
      case 'smile':
        return Icons.sentiment_very_satisfied_rounded;
      case ':100:':
        return Icons.looks_one_rounded;
      default:
        return null;
    }
  }

  Future<String?> _showThreadNameDialog() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => const _ThreadNameDialog(),
    );
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Widget _buildInlineThreadPicker({
    required List<ChatThread> threads,
    required String selectedThreadId,
    required Map<String, String> userMap,
    required String myId,
  }) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: context.appBorderRadius(12),
      ),
      child: Row(
        children: [
          Icon(Icons.tag, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                dropdownColor: Theme.of(context).colorScheme.surface,
                iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                iconDisabledColor: Theme.of(context).colorScheme.onSurface,
                focusColor: Theme.of(context).colorScheme.primary,

                value: selectedThreadId,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                items: threads
                    .map(
                      (thread) => DropdownMenuItem<String>(
                        value: thread.id,
                        child: Text(
                          _threadTitle(thread, userMap, myId),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (nextId) {
                  if (nextId == null) return;
                  setState(() => _selectedThreadId = nextId);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer({
    required bool canSend,
    required bool isExpired,
    required String selectedThreadId,
    required String myId,
    required List<ChatThread> threads,
    required List<UserProfile> profiles,
    required List<Role> roles,
    required List<LogicalGroup> logicalGroups,
    required bool canMentionEveryone,
    required bool canManageMembers,
    Widget? leading,
    required void Function(String text) onSend,
  }) {
    final hasSuggestions = _composerSuggestions.isNotEmpty;
    final modeBanner = _editingMessageId != null || _replyToMessageId != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: context.appBorderRadius(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _editingMessageId != null
                        ? 'Editing message'
                        : 'Replying to message',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _clearComposerMode,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14),
                  ),
                ),
              ],
            ),
          )
        : null;

    final messageInput = Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: context.appBorderRadius(12),
        ),
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (hasSuggestions) {
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                setState(() {
                  _composerSuggestionIndex =
                      (_composerSuggestionIndex + 1) %
                      _composerSuggestions.length;
                });
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                setState(() {
                  _composerSuggestionIndex =
                      (_composerSuggestionIndex - 1) %
                      _composerSuggestions.length;
                  if (_composerSuggestionIndex < 0) {
                    _composerSuggestionIndex += _composerSuggestions.length;
                  }
                });
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.tab ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                final targetIndex = _composerSuggestionIndex
                    .clamp(0, _composerSuggestions.length - 1)
                    .toInt();
                _applyComposerSuggestion(
                  suggestion: _composerSuggestions[targetIndex],
                  threadId: selectedThreadId,
                  userId: myId,
                  profiles: profiles,
                  roles: roles,
                  logicalGroups: logicalGroups,
                  threads: threads,
                  canMentionEveryone: canMentionEveryone,
                );
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                setState(_clearComposerSuggestions);
                return KeyEventResult.handled;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _clearComposerMode();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                _controller.text.trim().isEmpty &&
                _lastOwnMessageId != null) {
              _startEditingLastOwnMessage();
              return KeyEventResult.handled;
            }
            if ((HardwareKeyboard.instance.isMetaPressed ||
                    HardwareKeyboard.instance.isControlPressed) &&
                event.logicalKey == LogicalKeyboardKey.keyK) {
              _showThreadQuickSwitcher(
                selectedThreadId: selectedThreadId,
                myId: myId,
              );
              return KeyEventResult.handled;
            }
            if ((HardwareKeyboard.instance.isMetaPressed ||
                    HardwareKeyboard.instance.isControlPressed) &&
                event.logicalKey == LogicalKeyboardKey.keyF) {
              _showSearchDialog(
                repo: ref.read(dashboardRepositoryProvider),
                userMap: {
                  for (final profile in profiles)
                    profile.id: profile.displayName,
                },
                currentThreadId: selectedThreadId,
              );
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TextField(
                focusNode: _composerFocusNode,
                controller: _controller,
                enabled: canSend,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: isExpired
                      ? 'This channel has expired'
                      : _editingMessageId != null
                      ? 'Edit message...'
                      : (canSend ? 'Type a message...' : 'Read-only'),
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: canSend
                    ? (_) => _handleComposerChanged(
                        threadId: selectedThreadId,
                        userId: myId,
                        profiles: profiles,
                        roles: roles,
                        logicalGroups: logicalGroups,
                        threads: threads,
                        canMentionEveryone: canMentionEveryone,
                      )
                    : null,
                onTap: canSend
                    ? () => _handleComposerChanged(
                        threadId: selectedThreadId,
                        userId: myId,
                        profiles: profiles,
                        roles: roles,
                        logicalGroups: logicalGroups,
                        threads: threads,
                        canMentionEveryone: canMentionEveryone,
                      )
                    : null,
                onSubmitted: canSend ? (_) => onSend(_controller.text) : null,
              ),
              if (hasSuggestions)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 46,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 8,
                    borderRadius: context.appBorderRadius(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _composerSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _composerSuggestions[index];
                          final selected = index == _composerSuggestionIndex;
                          return InkWell(
                            onTap: () => _applyComposerSuggestion(
                              suggestion: suggestion,
                              threadId: selectedThreadId,
                              userId: myId,
                              profiles: profiles,
                              roles: roles,
                              logicalGroups: logicalGroups,
                              threads: threads,
                              canMentionEveryone: canMentionEveryone,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: selected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Icon(
                                    suggestion.icon,
                                    size: 16,
                                    color: selected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      suggestion.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    suggestion.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final sendButton = InkWell(
      onTap: canSend ? () => onSend(_controller.text) : null,
      borderRadius: context.appBorderRadius(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: canSend
              ? const Color(0xFF2563EB)
              : Theme.of(context).disabledColor,
          borderRadius: context.appBorderRadius(12),
        ),
        child: Icon(
          Icons.send,
          color: canSend
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(left: 8.0, top: 16),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackLeading = leading != null && constraints.maxWidth < 360;

            if (stackLeading) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leading,
                  const SizedBox(height: 8),
                  if (modeBanner != null) ...[
                    modeBanner,
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(child: messageInput),
                      const SizedBox(width: 4),
                      sendButton,
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 4)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (modeBanner != null) ...[
                        modeBanner,
                        const SizedBox(height: 4),
                      ],
                      messageInput,
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                sendButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleThreadAction({
    required _ThreadAction action,
    required List<UserProfile> profiles,
    required String myId,
    required bool canCreateChannels,
    required bool canStartDms,
  }) async {
    switch (action) {
      case _ThreadAction.createChannel:
        if (!canCreateChannels) return;
        await _showCreateChannelDialog(myId: myId);
        return;
      case _ThreadAction.startDm:
        if (!canStartDms) return;
        await _showStartDmDialog(profiles: profiles, myId: myId);
        return;
    }
  }

  List<PopupMenuEntry<_SelectedThreadAction>> _buildThreadActions({
    required ChatThread selectedThread,
    required String myId,
    required bool canEditChannels,
    required bool canDeleteChannels,
    required bool canLeaveDms,
  }) {
    if (selectedThread.isDm) {
      final canLeave =
          canLeaveDms && selectedThread.participantIds.contains(myId);
      if (!canLeave) return const [];
      return const [
        PopupMenuItem(
          value: _SelectedThreadAction.leaveDm,
          child: Text('Leave private chat'),
        ),
      ];
    }

    if (selectedThread.id == ChatThread.generalId) return const [];

    return [
      if (canEditChannels)
        const PopupMenuItem(
          value: _SelectedThreadAction.editChannel,
          child: Text('Edit channel'),
        ),
      if (canDeleteChannels)
        const PopupMenuItem(
          value: _SelectedThreadAction.deleteChannel,
          child: Text('Delete channel'),
        ),
    ];
  }

  Future<void> _handleSelectedThreadAction({
    required _SelectedThreadAction action,
    required ChatThread thread,
    required String myId,
  }) async {
    switch (action) {
      case _SelectedThreadAction.editChannel:
        await _showEditChannelDialog(thread);
        return;
      case _SelectedThreadAction.deleteChannel:
        await _deleteChannel(thread);
        return;
      case _SelectedThreadAction.leaveDm:
        await _leaveDm(thread, myId);
        return;
    }
  }

  Future<void> _showCreateChannelDialog({required String myId}) async {
    final groups = ref.read(logicalGroupsProvider);
    final draft = await showDialog<_CreateChannelDraft>(
      context: context,
      builder: (_) => _CreateChannelDialog(groups: groups),
    );
    if (draft == null) return;
    final now = DateTime.now();
    final repo = ref.read(dashboardRepositoryProvider);
    final visibilityGroupIds = normalizeVisibilityGroupIds(
      draft.visibilityGroupIds,
    );

    ChatThread? firstCreatedThread;
    if (draft.createPerAclGroup) {
      final groupsById = {for (final group in groups) group.id: group};
      final targetGroupIds = visibilityGroupIds
          .where((id) => id != AclGroupIds.everyone)
          .toList();

      for (final groupId in targetGroupIds) {
        final groupName = groupsById[groupId]?.name ?? groupId;
        final thread = ChatThread(
          id: 'chat:channel:${const Uuid().v4()}',
          kind: ChatThread.channelKind,
          name: _normalizeChannelName('${draft.name}-${groupName.trim()}'),
          createdBy: myId,
          createdAt: now,
          expiresAt: draft.ttl != null ? now.add(draft.ttl!) : null,
          visibilityGroupIds: [groupId],
        );
        await repo.saveChatThread(thread);
        firstCreatedThread ??= thread;
      }
    } else {
      final thread = ChatThread(
        id: 'chat:channel:${const Uuid().v4()}',
        kind: ChatThread.channelKind,
        name: _normalizeChannelName(draft.name),
        createdBy: myId,
        createdAt: now,
        expiresAt: draft.ttl != null ? now.add(draft.ttl!) : null,
        visibilityGroupIds: visibilityGroupIds,
      );
      await repo.saveChatThread(thread);
      firstCreatedThread = thread;
    }

    if (firstCreatedThread == null) return;
    final createdThreadId = firstCreatedThread.id;
    if (!mounted) return;
    setState(() => _selectedThreadId = createdThreadId);
  }

  Future<void> _showEditChannelDialog(ChatThread thread) async {
    if (!thread.isChannel || thread.id == ChatThread.generalId) return;

    final controller = TextEditingController(
      text: _normalizeChannelName(thread.name),
    );
    final updatedName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Channel'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Channel name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updatedName == null || updatedName.trim().isEmpty) return;
    final visibilityGroupIds = await _pickVisibilityGroups(
      initialSelection: thread.visibilityGroupIds,
    );
    if (visibilityGroupIds == null) return;

    await ref
        .read(dashboardRepositoryProvider)
        .saveChatThread(
          thread.copyWith(
            name: _normalizeChannelName(updatedName),
            visibilityGroupIds: visibilityGroupIds,
          ),
        );
  }

  Future<List<String>?> _pickVisibilityGroups({
    required List<String> initialSelection,
  }) async {
    final groups = ref.read(logicalGroupsProvider);
    return showVisibilityGroupSelectorDialog(
      context: context,
      groups: groups,
      initialSelection: normalizeVisibilityGroupIds(initialSelection),
    );
  }

  Future<void> _deleteChannel(ChatThread thread) async {
    if (!thread.isChannel || thread.id == ChatThread.generalId) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Channel?'),
        content: Text(
          'Delete "${_threadTitle(thread, const <String, String>{}, '')}" and all of its messages?',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: dialogDestructiveButtonStyle(context),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref
        .read(dashboardRepositoryProvider)
        .deleteChatThreadAndMessages(thread.id);
    if (!mounted) return;
    setState(() => _selectedThreadId = ChatThread.generalId);
  }

  Future<void> _leaveDm(ChatThread thread, String myId) async {
    if (!thread.isDm || myId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Private Chat?'),
        content: const Text(
          'You will no longer see this direct message thread unless you are re-added.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: dialogDestructiveButtonStyle(context),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref
        .read(dashboardRepositoryProvider)
        .leaveDirectMessageThread(threadId: thread.id, userId: myId);
    if (!mounted) return;
    setState(() => _selectedThreadId = ChatThread.generalId);
  }

  Future<void> _showStartDmDialog({
    required List<UserProfile> profiles,
    required String myId,
  }) async {
    if (myId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start DM until your identity is ready.'),
        ),
      );
      return;
    }

    final roomName = ref.read(dashboardRepositoryProvider).currentRoomName;
    if (roomName == null || roomName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to a group room before starting a DM.'),
        ),
      );
      return;
    }

    final hasPeer = profiles.any((profile) => profile.id != myId);
    if (!hasPeer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other members are available for DM.')),
      );
      return;
    }

    final selectedUserId = await showDialog<String>(
      context: context,
      builder: (_) => _StartPrivateChatDialog(profiles: profiles, myId: myId),
    );
    if (selectedUserId == null || selectedUserId.isEmpty) return;
    if (selectedUserId == myId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start a DM with yourself.')),
      );
      return;
    }

    late final ChatThread thread;
    try {
      thread = await ref
          .read(dashboardRepositoryProvider)
          .ensureDirectMessageThread(
            localUserId: myId,
            peerUserId: selectedUserId,
          );
    } catch (e) {
      debugPrint('[ChatWidget] Failed to create DM thread: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create DM. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _selectedThreadId = thread.id);
  }

  Future<void> _sendMessage(
    DashboardRepository repo,
    String content, {
    required String threadId,
    required String myId,
    required List<UserProfile> profiles,
    required List<Role> roles,
    required List<LogicalGroup> logicalGroups,
    required bool canMentionEveryone,
    required bool canManageMembers,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final slash = _slashParser.parse(trimmed);
    if (slash.handled) {
      if (slash.feedback != null && slash.feedback!.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(slash.feedback!)));
        return;
      }
      if (slash.presenceState != null) {
        setState(() => _presenceState = slash.presenceState!);
        await repo.touchPresence(userId: myId, state: slash.presenceState!);
        _controller.clear();
        if (mounted) setState(_clearComposerSuggestions);
        return;
      }
      if (slash.moderationAction != null) {
        if (!canManageMembers) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to moderate members.'),
            ),
          );
          return;
        }
        await _runSlashModeration(
          repo: repo,
          threadId: threadId,
          actorId: myId,
          profiles: profiles,
          action: slash.moderationAction!,
          targetHandle: slash.moderationTargetHandle ?? '',
          reason: slash.moderationReason,
        );
        _controller.clear();
        if (mounted) setState(_clearComposerSuggestions);
        return;
      }
      if (slash.threadName != null) {
        final parentId = _replyToMessageId;
        if (parentId == null || parentId.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reply to a message first, then run /thread.'),
            ),
          );
          return;
        }
        final created = await repo.createSubthreadFromMessage(
          parentMessageId: parentId,
          creatorId: myId,
          name: slash.threadName!,
        );
        _clearComposerMode();
        _controller.clear();
        if (!mounted) return;
        setState(() => _selectedThreadId = created.id);
        return;
      }
      content = slash.messageContent ?? trimmed;
    }

    if (_editingMessageId != null) {
      await repo.editMessage(
        messageId: _editingMessageId!,
        editorId: myId,
        content: content,
      );
      _clearComposerMode();
      _controller.clear();
      await repo.touchTyping(threadId: threadId, userId: myId, isTyping: false);
      return;
    }

    final sync = ref.read(syncServiceProvider);
    final roomName = sync.currentRoomName;
    final senderId = roomName == null
        ? sync.identity
        : (sync.getLocalParticipantIdForRoom(roomName) ?? sync.identity);
    if (senderId == null || senderId.isEmpty) {
      return;
    }

    final mentions = _mentionParser.parse(
      content: content,
      users: profiles,
      roles: roles,
      aclGroups: logicalGroups,
      canMentionEveryone: canMentionEveryone,
    );
    if ((content.contains('@everyone') || content.contains('@here')) &&
        !canMentionEveryone &&
        !mentions.mentionsEveryone) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to mention everyone.'),
        ),
      );
    }

    final time = ref.read(hybridTimeServiceProvider);
    final logicalTime = time.nextLogicalTime();
    final msg = ChatMessage(
      id: 'msg:${const Uuid().v4()}',
      senderId: senderId,
      threadId: threadId,
      content: content.trim(),
      timestamp: time.getAdjustedTimeLocal(),
      logicalTime: logicalTime,
      replyToMessageId: _replyToMessageId,
      mentionUserIds: mentions.userIds,
      mentionRoleIds: mentions.roleIds,
      mentionAclGroupIds: mentions.aclGroupIds,
      mentionsEveryone: mentions.mentionsEveryone,
    );

    await repo.saveMessage(msg);
    _lastOwnMessageId = msg.id;
    _clearComposerMode();
    _controller.clear();
    await repo.touchTyping(threadId: threadId, userId: myId, isTyping: false);
  }

  void _clearComposerMode() {
    setState(() {
      _replyToMessageId = null;
      _editingMessageId = null;
      _clearComposerSuggestions();
    });
  }

  Future<void> _startEditingLastOwnMessage() async {
    final id = _lastOwnMessageId;
    if (id == null || id.isEmpty) return;
    final message = await ref
        .read(dashboardRepositoryProvider)
        .getMessageById(id);
    if (message == null || message.isDeleted) return;
    if (!mounted) return;
    setState(() {
      _editingMessageId = id;
      _controller.text = message.content;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _handleComposerChanged({
    required String threadId,
    required String userId,
    required List<UserProfile> profiles,
    required List<Role> roles,
    required List<LogicalGroup> logicalGroups,
    required List<ChatThread> threads,
    required bool canMentionEveryone,
  }) {
    if (threadId.isEmpty || userId.isEmpty) return;
    _updateComposerSuggestions(
      profiles: profiles,
      roles: roles,
      logicalGroups: logicalGroups,
      threads: threads,
      canMentionEveryone: canMentionEveryone,
    );
    _typingTimer?.cancel();
    unawaited(
      ref
          .read(dashboardRepositoryProvider)
          .touchTyping(
            threadId: threadId,
            userId: userId,
            isTyping: _controller.text.trim().isNotEmpty,
          ),
    );
    _typingTimer = Timer(const Duration(seconds: 3), () {
      unawaited(
        ref
            .read(dashboardRepositoryProvider)
            .touchTyping(threadId: threadId, userId: userId, isTyping: false),
      );
    });
  }

  void _updateComposerSuggestions({
    required List<UserProfile> profiles,
    required List<Role> roles,
    required List<LogicalGroup> logicalGroups,
    required List<ChatThread> threads,
    required bool canMentionEveryone,
  }) {
    void clearIfNeeded() {
      if (_composerSuggestionStart == null && _composerSuggestions.isEmpty) {
        return;
      }
      setState(_clearComposerSuggestions);
    }

    final selection = _controller.selection;
    final text = _controller.text;
    final caret = selection.baseOffset;
    if (caret < 0 || caret > text.length) {
      clearIfNeeded();
      return;
    }

    final beforeCaret = text.substring(0, caret);
    final tokenPattern = RegExp(r'(^|\s)([@#])([A-Za-z0-9_.\-]*)$');
    final match = tokenPattern.firstMatch(beforeCaret);
    if (match == null) {
      clearIfNeeded();
      return;
    }
    final trigger = match.group(2);
    if (trigger == null) {
      clearIfNeeded();
      return;
    }
    final query = (match.group(3) ?? '').toLowerCase();
    final tokenStart = match.end - query.length - 1;

    var nextSuggestions = <_ComposerSuggestion>[];
    if (trigger == '@') {
      nextSuggestions = _buildMentionSuggestions(
        query: query,
        profiles: profiles,
        roles: roles,
        logicalGroups: logicalGroups,
        canMentionEveryone: canMentionEveryone,
      );
    } else if (trigger == '#') {
      nextSuggestions = _buildThreadMentionSuggestions(
        query: query,
        threads: threads,
      );
    }

    if (nextSuggestions.isEmpty) {
      clearIfNeeded();
      return;
    }
    setState(() {
      _composerSuggestionStart = tokenStart;
      _composerSuggestions = nextSuggestions;
      if (_composerSuggestionIndex >= _composerSuggestions.length) {
        _composerSuggestionIndex = 0;
      }
    });
  }

  List<_ComposerSuggestion> _buildMentionSuggestions({
    required String query,
    required List<UserProfile> profiles,
    required List<Role> roles,
    required List<LogicalGroup> logicalGroups,
    required bool canMentionEveryone,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final suggestions = <_ComposerSuggestion>[];

    bool matches(String value) {
      if (normalizedQuery.isEmpty) return true;
      return value.toLowerCase().contains(normalizedQuery);
    }

    if (canMentionEveryone) {
      if (matches('everyone')) {
        suggestions.add(
          const _ComposerSuggestion(
            kind: _ComposerSuggestionKind.mention,
            id: 'everyone',
            label: '@everyone',
            insertText: '@everyone',
            subtitle: 'All members',
            icon: Icons.groups_2_outlined,
          ),
        );
      }
      if (matches('here')) {
        suggestions.add(
          const _ComposerSuggestion(
            kind: _ComposerSuggestionKind.mention,
            id: 'here',
            label: '@here',
            insertText: '@here',
            subtitle: 'Online members',
            icon: Icons.alternate_email,
          ),
        );
      }
    }

    final sortedRoles = [...roles]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final role in sortedRoles) {
      if (!matches(role.name)) continue;
      final handle = _normalizeMentionHandle(role.name);
      suggestions.add(
        _ComposerSuggestion(
          kind: _ComposerSuggestionKind.mention,
          id: 'role:${role.id}',
          label: '@${role.name}',
          insertText: '@$handle',
          subtitle: 'Role',
          icon: Icons.shield_outlined,
        ),
      );
      if (suggestions.length >= 12) break;
    }

    final sortedGroups = [
      ...logicalGroups.where((group) => group.id != AclGroupIds.everyone),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final group in sortedGroups) {
      if (!matches(group.name)) continue;
      final handle = _normalizeMentionHandle(group.name);
      suggestions.add(
        _ComposerSuggestion(
          kind: _ComposerSuggestionKind.mention,
          id: 'acl:${group.id}',
          label: '@${group.name}',
          insertText: '@$handle',
          subtitle: 'ACL group',
          icon: Icons.group_work_outlined,
        ),
      );
      if (suggestions.length >= 12) break;
    }

    final sortedUsers = [...profiles]
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    for (final user in sortedUsers) {
      if (!matches(user.displayName)) continue;
      final handle = _normalizeMentionHandle(user.displayName);
      suggestions.add(
        _ComposerSuggestion(
          kind: _ComposerSuggestionKind.mention,
          id: 'user:${user.id}',
          label: '@${user.displayName}',
          insertText: '@$handle',
          subtitle: 'Member',
          icon: Icons.person_outline,
        ),
      );
      if (suggestions.length >= 12) break;
    }

    return suggestions.take(8).toList();
  }

  List<_ComposerSuggestion> _buildThreadMentionSuggestions({
    required String query,
    required List<ChatThread> threads,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final candidates =
        threads
            .where((thread) => !thread.isDm)
            .map((thread) {
              final normalizedName = _normalizeChannelName(thread.name);
              return (thread: thread, normalizedName: normalizedName);
            })
            .where((entry) {
              if (normalizedQuery.isEmpty) return true;
              return entry.normalizedName.toLowerCase().contains(
                normalizedQuery,
              );
            })
            .toList()
          ..sort((a, b) {
            final aName = a.normalizedName.toLowerCase();
            final bName = b.normalizedName.toLowerCase();
            final aStarts = aName.startsWith(normalizedQuery);
            final bStarts = bName.startsWith(normalizedQuery);
            if (aStarts != bStarts) {
              return aStarts ? -1 : 1;
            }
            return aName.compareTo(bName);
          });

    return candidates.take(8).map((entry) {
      final thread = entry.thread;
      final normalizedName = entry.normalizedName;
      return _ComposerSuggestion(
        kind: _ComposerSuggestionKind.thread,
        id: 'thread:${thread.id}',
        label: '#$normalizedName',
        insertText: '#$normalizedName',
        subtitle: thread.isSubthread ? 'Thread' : 'Channel',
        icon: thread.isSubthread ? Icons.forum_outlined : Icons.tag,
      );
    }).toList();
  }

  String _normalizeMentionHandle(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'\s+'), '.');
  }

  void _applyComposerSuggestion({
    required _ComposerSuggestion suggestion,
    required String threadId,
    required String userId,
    required List<UserProfile> profiles,
    required List<Role> roles,
    required List<LogicalGroup> logicalGroups,
    required List<ChatThread> threads,
    required bool canMentionEveryone,
  }) {
    final selection = _controller.selection;
    final end = selection.baseOffset;
    final start = _composerSuggestionStart;
    if (start == null ||
        start < 0 ||
        end < start ||
        end > _controller.text.length) {
      return;
    }
    final replacement = '${suggestion.insertText} ';
    final updated = _controller.text.replaceRange(start, end, replacement);
    final offset = start + replacement.length;
    _controller.value = _controller.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
    _composerFocusNode.requestFocus();
    _handleComposerChanged(
      threadId: threadId,
      userId: userId,
      profiles: profiles,
      roles: roles,
      logicalGroups: logicalGroups,
      threads: threads,
      canMentionEveryone: canMentionEveryone,
    );
  }

  void _clearComposerSuggestions() {
    _composerSuggestionStart = null;
    _composerSuggestions = const [];
    _composerSuggestionIndex = 0;
  }

  Future<void> _runSlashModeration({
    required DashboardRepository repo,
    required String threadId,
    required String actorId,
    required List<UserProfile> profiles,
    required String action,
    required String targetHandle,
    required String reason,
  }) async {
    final target = _resolveUserIdFromHandle(targetHandle, profiles);
    if (target == null || target.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Target user not found.')));
      return;
    }
    await repo.saveModerationEvent(
      ChatModerationEvent(
        id: 'mod:${const Uuid().v4()}',
        action: action,
        actorId: actorId,
        targetUserId: target,
        threadId: threadId,
        reason: reason,
        timestamp: ref.read(hybridTimeServiceProvider).getAdjustedTimeLocal(),
        logicalTime: ref.read(hybridTimeServiceProvider).nextLogicalTime(),
      ),
    );
  }

  String? _resolveUserIdFromHandle(
    String rawHandle,
    List<UserProfile> profiles,
  ) {
    final normalized = rawHandle
        .trim()
        .replaceFirst('@', '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '.');
    if (normalized.isEmpty) return null;
    for (final profile in profiles) {
      final handle = profile.displayName.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        '.',
      );
      if (handle == normalized) return profile.id;
    }
    return null;
  }

  Future<void> _reportMessage({
    required ChatMessage message,
    required String action,
    required String myId,
    required String reason,
  }) async {
    await ref
        .read(dashboardRepositoryProvider)
        .saveModerationEvent(
          ChatModerationEvent(
            id: 'mod:${const Uuid().v4()}',
            action: action,
            actorId: myId,
            targetUserId: message.senderId,
            threadId: message.threadId,
            messageId: message.id,
            reason: reason,
            timestamp: ref
                .read(hybridTimeServiceProvider)
                .getAdjustedTimeLocal(),
            logicalTime: ref.read(hybridTimeServiceProvider).nextLogicalTime(),
          ),
        );
  }

  Future<void> _showThreadQuickSwitcher({
    required String selectedThreadId,
    required String myId,
  }) async {
    final threads = await ref.read(chatThreadsStreamProvider.future);
    final userMap = {
      for (final profile in await ref.read(userProfilesProvider.future))
        profile.id: profile.displayName,
    };
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _ThreadQuickSwitcherDialog(
        threads: threads,
        userMap: userMap,
        myId: myId,
        selectedThreadId: selectedThreadId,
        titleBuilder: _threadTitle,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    if (!mounted) return;
    setState(() => _selectedThreadId = selected);
  }

  Future<void> _showPinnedMessagesDialog(List<ChatMessage> messages) async {
    final pinned = messages.where((m) => m.isPinned).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pinned Messages'),
        content: SizedBox(
          width: 420,
          height: 320,
          child: pinned.isEmpty
              ? const Center(child: Text('No pinned messages.'))
              : ListView.builder(
                  itemCount: pinned.length,
                  itemBuilder: (context, index) {
                    final message = pinned[index];
                    return ListTile(
                      title: Text(
                        message.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_formatMessageTime(message.timestamp)),
                      onTap: () {
                        if (!mounted) return;
                        setState(() => _selectedThreadId = message.threadId);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchDialog({
    required DashboardRepository repo,
    required Map<String, String> userMap,
    required String currentThreadId,
  }) async {
    final queryController = TextEditingController();
    final authorController = TextEditingController();
    bool hasReply = false;
    bool hasMention = false;
    bool inCurrentThread = true;
    DateTime? from;
    DateTime? to;
    List<ChatSearchResult> results = const <ChatSearchResult>[];

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> runSearch() async {
            results = await repo.searchMessages(
              ChatSearchQuery(
                keyword: queryController.text,
                threadId: inCurrentThread ? currentThreadId : null,
                authorId: authorController.text.trim().isEmpty
                    ? null
                    : authorController.text.trim(),
                from: from,
                to: to,
                hasReply: hasReply,
                hasMention: hasMention,
              ),
              limit: 200,
            );
            setStateDialog(() {});
          }

          return AlertDialog(
            title: const Text('Search Messages'),
            content: SizedBox(
              width: 560,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: queryController,
                    decoration: const InputDecoration(
                      labelText: 'Keyword',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => runSearch(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author ID (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: inCurrentThread,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Current thread only'),
                          onChanged: (value) {
                            setStateDialog(
                              () => inCurrentThread = value ?? true,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          value: hasReply,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Has reply'),
                          onChanged: (value) {
                            setStateDialog(() => hasReply = value ?? false);
                          },
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          value: hasMention,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Has mention'),
                          onChanged: (value) {
                            setStateDialog(() => hasMention = value ?? false);
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: from ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setStateDialog(() => from = picked);
                            }
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                            from == null
                                ? 'From date'
                                : 'From ${from!.toIso8601String().substring(0, 10)}',
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: to ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setStateDialog(() => to = picked);
                            }
                          },
                          icon: const Icon(Icons.event_available),
                          label: Text(
                            to == null
                                ? 'To date'
                                : 'To ${to!.toIso8601String().substring(0, 10)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Text('No results yet.'))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final result = results[index];
                              return ListTile(
                                title: Text(result.snippet),
                                subtitle: Text(
                                  '${userMap[result.message.senderId] ?? result.message.senderId} • ${_formatMessageTime(result.message.timestamp)}',
                                ),
                                onTap: () {
                                  if (!mounted) return;
                                  setState(
                                    () => _selectedThreadId =
                                        result.message.threadId,
                                  );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(onPressed: runSearch, child: const Text('Search')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showModerationLogDialog({
    required String threadId,
    required Map<String, String> userMap,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Moderation Log'),
        content: SizedBox(
          width: 520,
          height: 360,
          child: Consumer(
            builder: (context, ref, _) {
              final eventsAsync = ref.watch(moderationEventsProvider(threadId));
              return eventsAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return const Center(child: Text('No moderation events.'));
                  }
                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final actor = userMap[event.actorId] ?? event.actorId;
                      final target =
                          userMap[event.targetUserId] ?? event.targetUserId;
                      return ListTile(
                        dense: true,
                        title: Text('${event.action.toUpperCase()} • $target'),
                        subtitle: Text(
                          '$actor • ${event.reason} • ${event.timestamp.toIso8601String()}',
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) =>
                    Center(child: Text('Error loading log: $err')),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChatHistory(
    DashboardRepository repo,
    ChatThread thread,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will permanently delete all messages in this channel for everyone.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: dialogDestructiveButtonStyle(context),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await repo.clearChatMessages(thread.id);
  }

  String _threadTitle(
    ChatThread thread,
    Map<String, String> userMap,
    String myId,
  ) {
    if (!thread.isDm) return _normalizeChannelName(thread.name);
    final otherId = thread.participantIds.firstWhere(
      (id) => id != myId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return thread.name;
    final name = userMap[otherId];
    if (name == null || name.trim().isEmpty) return 'Direct message';
    return name.trim();
  }

  String _threadSubtitle(ChatThread thread) {
    if (thread.isSubthread) {
      return thread.isArchived ? 'Thread • archived' : 'Thread';
    }
    if (thread.expiresAt == null) {
      return thread.isDm ? 'Private' : 'Channel';
    }
    final now = DateTime.now();
    final remaining = thread.expiresAt!.difference(now);
    if (remaining.isNegative) return 'Expired';
    if (remaining.inMinutes < 1) return 'Expires in <1m';
    if (remaining.inMinutes < 60) return 'Expires in ${remaining.inMinutes}m';
    if (remaining.inHours < 24) return 'Expires in ${remaining.inHours}h';
    return 'Expires in ${remaining.inDays}d';
  }

  String _normalizeChannelName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'general';
    return trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
  }

  String _formatMessageTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Color _usernameColor({
    required String senderId,
    required bool isMe,
    required ThemeData theme,
  }) {
    if (isMe) return theme.colorScheme.primary;
    const palette = <Color>[
      Color(0xFF60A5FA),
      Color(0xFF34D399),
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
      Color(0xFFA78BFA),
      Color(0xFF22D3EE),
      Color(0xFFFB7185),
    ];
    final idx = senderId.hashCode.abs() % palette.length;
    return palette[idx];
  }
}

final chatThreadsStreamProvider = StreamProvider<List<ChatThread>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final myGroupIds = ref.watch(myLogicalGroupIdsProvider);
  final isOwner = ref.watch(currentUserIsOwnerProvider);
  final permissions = ref.watch(currentUserPermissionsProvider).value;
  final myId = ref.watch(syncServiceProvider.select((s) => s.identity)) ?? '';
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));

  return repo.watchChatThreads().map((threads) {
    return threads.where((thread) {
      if (thread.isDm) return true;
      if (thread.isSubthread &&
          thread.memberIds.isNotEmpty &&
          !thread.memberIds.contains(myId)) {
        return false;
      }
      return canViewByLogicalGroups(
        itemGroupIds: thread.visibilityGroupIds,
        viewerGroupIds: myGroupIds,
        bypass: bypass,
      );
    }).toList();
  });
});

final threadMessagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, threadId) {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.watchMessagesForThread(threadId);
    });

final typingStatesProvider =
    StreamProvider.family<List<ChatTypingState>, String>((ref, threadId) {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.watchTypingStates(threadId);
    });

final chatPresenceStreamProvider = StreamProvider<List<ChatUserPresence>>((
  ref,
) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchPresence();
});

final moderationEventsProvider =
    StreamProvider.family<List<ChatModerationEvent>, String>((ref, threadId) {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.watchModerationEvents(threadId: threadId);
    });

final chatClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});

class _ThreadQuickSwitcherDialog extends StatefulWidget {
  final List<ChatThread> threads;
  final Map<String, String> userMap;
  final String myId;
  final String selectedThreadId;
  final String Function(
    ChatThread thread,
    Map<String, String> userMap,
    String myId,
  )
  titleBuilder;

  const _ThreadQuickSwitcherDialog({
    required this.threads,
    required this.userMap,
    required this.myId,
    required this.selectedThreadId,
    required this.titleBuilder,
  });

  @override
  State<_ThreadQuickSwitcherDialog> createState() =>
      _ThreadQuickSwitcherDialogState();
}

class _ThreadQuickSwitcherDialogState
    extends State<_ThreadQuickSwitcherDialog> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final filtered = widget.threads.where((thread) {
      if (query.isEmpty) return true;
      final title = widget
          .titleBuilder(thread, widget.userMap, widget.myId)
          .toLowerCase();
      return title.contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('Quick Switcher'),
      content: SizedBox(
        width: 460,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Jump to channel or DM',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matches.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final thread = filtered[index];
                        final selected = thread.id == widget.selectedThreadId;
                        return ListTile(
                          selected: selected,
                          title: Text(
                            widget.titleBuilder(
                              thread,
                              widget.userMap,
                              widget.myId,
                            ),
                          ),
                          subtitle: Text(
                            thread.isDm
                                ? 'Private'
                                : (thread.isSubthread ? 'Thread' : 'Channel'),
                          ),
                          onTap: () => Navigator.pop(context, thread.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ThreadNameDialog extends StatefulWidget {
  const _ThreadNameDialog();

  @override
  State<_ThreadNameDialog> createState() => _ThreadNameDialogState();
}

class _ThreadNameDialogState extends State<_ThreadNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Thread'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Thread name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CreateChannelDraft {
  final String name;
  final Duration? ttl;
  final List<String> visibilityGroupIds;
  final bool createPerAclGroup;

  const _CreateChannelDraft({
    required this.name,
    required this.ttl,
    required this.visibilityGroupIds,
    required this.createPerAclGroup,
  });
}

class _CreateChannelDialog extends StatefulWidget {
  final List<LogicalGroup> groups;

  const _CreateChannelDialog({required this.groups});

  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _nameController = TextEditingController();
  Duration? _selectedTtl;
  List<String> _visibilityGroupIds = const [AclGroupIds.everyone];
  bool _createPerAclGroup = false;

  static const _ttlOptions = <({String label, Duration? ttl})>[
    (label: 'No expiry', ttl: null),
    (label: '30 minutes', ttl: Duration(minutes: 30)),
    (label: '1 hour', ttl: Duration(hours: 1)),
    (label: '6 hours', ttl: Duration(hours: 6)),
    (label: '24 hours', ttl: Duration(hours: 24)),
    (label: '3 days', ttl: Duration(days: 3)),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSpecificAclSelection = _visibilityGroupIds.any(
      (id) => id != AclGroupIds.everyone,
    );
    return AlertDialog(
      title: const Text('Create Channel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Channel name',
              hintText: 'release-planning',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Duration?>(
            initialValue: _selectedTtl,
            decoration: const InputDecoration(
              labelText: 'Room lifetime',
              border: OutlineInputBorder(),
            ),
            items: _ttlOptions
                .map(
                  (option) => DropdownMenuItem<Duration?>(
                    value: option.ttl,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedTtl = value),
          ),
          const SizedBox(height: 12),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Visibility'),
            subtitle: Text(
              visibilitySelectionSummary(
                selectedGroupIds: _visibilityGroupIds,
                allGroups: widget.groups,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showVisibilityGroupSelectorDialog(
                context: context,
                groups: widget.groups,
                initialSelection: _visibilityGroupIds,
              );
              if (picked == null) return;
              setState(() {
                _visibilityGroupIds = normalizeVisibilityGroupIds(picked);
                if (!_visibilityGroupIds.any(
                  (id) => id != AclGroupIds.everyone,
                )) {
                  _createPerAclGroup = false;
                }
              });
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Create ACL rooms'),
            subtitle: const Text(
              'Create one room per selected ACL group (excludes Everyone).',
            ),
            value: _createPerAclGroup,
            onChanged: hasSpecificAclSelection
                ? (value) => setState(() => _createPerAclGroup = value)
                : null,
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _CreateChannelDraft(
                name: name,
                ttl: _selectedTtl,
                visibilityGroupIds: _visibilityGroupIds,
                createPerAclGroup: _createPerAclGroup,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _StartPrivateChatDialog extends StatelessWidget {
  final List<UserProfile> profiles;
  final String myId;

  const _StartPrivateChatDialog({required this.profiles, required this.myId});

  @override
  Widget build(BuildContext context) {
    final others = profiles.where((profile) => profile.id != myId).toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

    return AlertDialog(
      title: const Text('Start Private Chat'),
      content: SizedBox(
        width: 360,
        height: 300,
        child: others.isEmpty
            ? const Center(child: Text('No other members available.'))
            : ListView.builder(
                itemCount: others.length,
                itemBuilder: (context, index) {
                  final profile = others[index];
                  final title = profile.displayName.trim().isEmpty
                      ? 'Member'
                      : profile.displayName.trim();
                  return ListTile(
                    title: Text(title),
                    onTap: () => Navigator.pop(context, profile.id),
                  );
                },
              ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
