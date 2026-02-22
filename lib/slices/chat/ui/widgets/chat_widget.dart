import 'package:flutter/material.dart';
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
import 'package:cohortz/slices/permissions_feature/ui/widgets/visibility_group_selector.dart';

enum _ThreadAction { createChannel, startDm }

enum _SelectedThreadAction { editChannel, deleteChannel, leaveDm }

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
  final _controller = TextEditingController();
  String _selectedThreadId = ChatThread.generalId;
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
    _readReceiptSubscription?.close();
    _readReceiptController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatClockProvider);
    final repo = ref.watch(dashboardRepositoryProvider);
    final profilesAsync = ref.watch(userProfilesProvider);
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

    return threadsAsync.when(
      data: (threads) {
        final profiles = profilesAsync.value ?? const <UserProfile>[];
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
                          canEditChat: canEditChat,
                          canEditChannels: canEditChannels || canManageChat,
                          canDeleteChannels: canDeleteChannels || canManageChat,
                          canLeaveDms: canLeaveDms || canManageChat,
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
          .where((thread) => thread.kind == ChatThread.channelKind)
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
  }

  void _markThreadRead(String threadId, String groupId) {
    if (groupId.isEmpty) return;

    final bool isVisible =
        widget.isFullPage ||
        (widget.isAccordion && widget.isOpen) ||
        (!widget.isFullPage && !widget.isAccordion && widget.isOpen);

    if (!isVisible) return;

    final now = ref.read(hybridTimeServiceProvider).getAdjustedTimeUtcMs();
    _readReceiptController.markVisible(
      groupId: groupId,
      threadId: threadId,
      timestampMs: now,
    );
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
                borderRadius: BorderRadius.circular(10),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    required bool canEditChat,
    required bool canEditChannels,
    required bool canDeleteChannels,
    required bool canLeaveDms,
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
              messages: messages,
              userMap: userMap,
              myId: myId,
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
        _buildComposer(
          canSend: canSend,
          isExpired: isExpired,
          leading: showInlineThreadPicker
              ? _buildInlineThreadPicker(
                  threads: threads,
                  selectedThreadId: selectedThreadId,
                  userMap: userMap,
                  myId: myId,
                )
              : null,
          onSend: (text) =>
              _sendMessage(repo, text, threadId: selectedThread.id),
        ),
      ],
    );
  }

  Widget _buildMessagesList({
    required List<ChatMessage> messages,
    required Map<String, String> userMap,
    required String myId,
  }) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }

    final reversedMessages = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      itemCount: reversedMessages.length,
      itemBuilder: (context, index) {
        final msg = reversedMessages[index];
        final isMe = msg.senderId == myId;
        final displayName = isMe ? 'You' : (userMap[msg.senderId] ?? 'Member');
        final timeText = _formatMessageTime(msg.timestamp);
        final nameColor = _usernameColor(
          senderId: msg.senderId,
          isMe: isMe,
          theme: Theme.of(context),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  timeText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: displayName,
                          style: TextStyle(
                            color: nameColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: msg.content,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.left,
                    softWrap: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
        borderRadius: BorderRadius.circular(12),
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
    Widget? leading,
    required void Function(String text) onSend,
  }) {
    final messageInput = Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _controller,
          enabled: canSend,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: isExpired
                ? 'This channel has expired'
                : (canSend ? 'Type a message...' : 'Read-only'),
            hintStyle: TextStyle(color: Theme.of(context).hintColor),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: InputBorder.none,
          ),
          onSubmitted: canSend ? onSend : null,
        ),
      ),
    );

    final sendButton = InkWell(
      onTap: canSend ? () => onSend(_controller.text) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: canSend
              ? const Color(0xFF2563EB)
              : Theme.of(context).disabledColor,
          borderRadius: BorderRadius.circular(12),
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
                Expanded(child: messageInput),
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
    final draft = await showDialog<_CreateChannelDraft>(
      context: context,
      builder: (_) => const _CreateChannelDialog(),
    );
    if (draft == null) return;
    final visibilityGroupIds = await _pickVisibilityGroups(
      initialSelection: const [AclGroupIds.everyone],
    );
    if (visibilityGroupIds == null) return;

    final now = DateTime.now();
    final thread = ChatThread(
      id: 'chat:channel:${const Uuid().v4()}',
      kind: ChatThread.channelKind,
      name: _normalizeChannelName(draft.name),
      createdBy: myId,
      createdAt: now,
      expiresAt: draft.ttl != null ? now.add(draft.ttl!) : null,
      visibilityGroupIds: visibilityGroupIds,
    );
    await ref.read(dashboardRepositoryProvider).saveChatThread(thread);
    if (!mounted) return;
    setState(() => _selectedThreadId = thread.id);
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

  void _sendMessage(
    DashboardRepository repo,
    String content, {
    required String threadId,
  }) {
    if (content.trim().isEmpty) return;

    final sync = ref.read(syncServiceProvider);
    final roomName = sync.currentRoomName;
    final senderId = roomName == null
        ? sync.identity
        : (sync.getLocalParticipantIdForRoom(roomName) ?? sync.identity);
    if (senderId == null || senderId.isEmpty) {
      return;
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
    );

    repo.saveMessage(msg);
    _controller.clear();
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
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));

  return repo.watchChatThreads().map((threads) {
    return threads.where((thread) {
      if (thread.isDm) return true;
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

final chatClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});

class _CreateChannelDraft {
  final String name;
  final Duration? ttl;

  const _CreateChannelDraft({required this.name, required this.ttl});
}

class _CreateChannelDialog extends StatefulWidget {
  const _CreateChannelDialog();

  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _nameController = TextEditingController();
  Duration? _selectedTtl;

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
              _CreateChannelDraft(name: name, ttl: _selectedTtl),
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
                    leading: CircleAvatar(
                      child: Text(title.substring(0, 1).toUpperCase()),
                    ),
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
