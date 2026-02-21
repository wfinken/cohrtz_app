import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/permissions/permission_flags.dart';
import '../../../../core/permissions/permission_providers.dart';
import '../../../../core/permissions/permission_utils.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/dialog_button_styles.dart';
import '../../domain/note_model.dart';
import '../../../dashboard/presentation/widgets/ghost_add_button.dart';

enum _NotesMode { write, preview }

enum _NotesView { list, editor }

class NotesWidget extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry padding;
  final String? initialDocumentId;
  final ValueChanged<String>? onDocumentChanged;

  const NotesWidget({
    super.key,
    this.padding = EdgeInsets.zero,
    this.initialDocumentId,
    this.onDocumentChanged,
  });

  @override
  ConsumerState<NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends ConsumerState<NotesWidget> {
  static const _defaultDocumentId = 'note:shared';
  static const _presenceHeartbeatInterval = Duration(seconds: 8);

  final _titleController = TextEditingController();
  final _editorController = TextEditingController();
  final _editorFocusNode = FocusNode();
  final _uuid = const Uuid();

  _NotesMode _mode = _NotesMode.preview;
  _NotesView _currentView = _NotesView.list;
  String? _activeDocumentId;
  bool _isApplyingDocumentState = false;
  bool _isDirty = false;
  bool _isEditingTitle = false;
  bool _isCreatingDefault = false;

  final _titleFocusNode = FocusNode();

  Timer? _saveDebounce;
  Timer? _presenceHeartbeat;

  String? _presenceDocumentId;
  Stream<List<NoteEditorPresence>>? _presenceStream;

  @override
  void initState() {
    super.initState();
    _initializeView();
    _titleController.addListener(_onLocalDocumentEdit);
    _editorController.addListener(_onLocalDocumentEdit);
    _editorFocusNode.addListener(_handleEditorFocusChanged);
    _titleFocusNode.addListener(_handleEditorFocusChanged);
  }

  void _initializeView() {
    if (widget.initialDocumentId != null &&
        widget.initialDocumentId!.isNotEmpty) {
      if (widget.initialDocumentId == 'note:create') {
        _createDocument();
      } else {
        _activeDocumentId = widget.initialDocumentId;
        _currentView = _NotesView.editor;
      }
    } else {
      _currentView = _NotesView.list;
    }
  }

  @override
  void didUpdateWidget(covariant NotesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDocumentId != oldWidget.initialDocumentId) {
      if (widget.initialDocumentId == 'note:create') {
        _createDocument();
      } else if (widget.initialDocumentId != null &&
          widget.initialDocumentId!.isNotEmpty) {
        setState(() {
          _activeDocumentId = widget.initialDocumentId;
          _currentView = _NotesView.editor;
          _isDirty = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _presenceHeartbeat?.cancel();
    _titleController.dispose();
    _editorController.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomName = ref.watch(
      syncServiceProvider.select((service) => service.currentRoomName),
    );
    if (roomName == null || roomName.isEmpty) {
      return _buildCenteredMessage(
        context,
        icon: Icons.edit_off_outlined,
        title: 'Connect to a group to edit notes',
      );
    }

    final notesAsync = ref.watch(notesListProvider);
    final currentUserId = ref.watch(
      syncServiceProvider.select((service) => service.identity),
    );
    final connectedParticipants = ref.watch(
      connectedParticipantIdentitiesProvider,
    );
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);

    return permissionsAsync.when(
      data: (permissions) {
        final canViewNotes = PermissionUtils.has(
          permissions,
          PermissionFlags.viewNotes,
        );
        if (!canViewNotes) {
          return _buildCenteredMessage(
            context,
            icon: Icons.lock_outline,
            title: 'Notes are locked',
            subtitle: 'You do not have access to notes.',
          );
        }

        final canEditNotes = PermissionUtils.has(
          permissions,
          PermissionFlags.editNotes,
        );
        final canManageNotes = PermissionUtils.has(
          permissions,
          PermissionFlags.manageNotes,
        );
        final canCreateNotes = PermissionUtils.has(
          permissions,
          PermissionFlags.createNotes,
        );
        final isAdmin = PermissionUtils.has(
          permissions,
          PermissionFlags.administrator,
        );

        final canAdd = canCreateNotes || canManageNotes || isAdmin;

        if (!canEditNotes && _mode == _NotesMode.write) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _mode = _NotesMode.preview);
          });
        }

        return notesAsync.when(
          data: (documents) {
            if (_currentView == _NotesView.list) {
              return _buildNotesList(
                context,
                documents,
                canAdd,
                canManageNotes,
              );
            }

            if (documents.isEmpty && _currentView == _NotesView.editor) {
              // Fallback if we are in editor mode but no documents exist (e.g. deleted)
              // unless we are creating one currently, handled by _createDocument
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isCreatingDefault) {
                  setState(() {
                    _currentView = _NotesView.list;
                  });
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            // Ensure active document exists
            final activeDocument = _resolveActiveDocument(documents);
            if (activeDocument == null) {
              return _buildNotesList(
                context,
                documents,
                canAdd,
                canManageNotes,
              );
            }

            _syncDocumentState(activeDocument);
            _syncPresenceStream(activeDocument.id);

            final currentEditors = _presenceStream == null
                ? Stream.value(const <NoteEditorPresence>[])
                : _presenceStream!;

            return Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  _buildTopRow(
                    context,
                    documents,
                    activeDocument,
                    currentEditors,
                    connectedParticipants,
                    currentUserId,
                    canEditNotes,
                    canManageNotes,
                    canAdd,
                  ),
                  _buildModeBar(context, canEditNotes),
                  if (canEditNotes) _buildToolbar(context),
                  Expanded(
                    child: _mode == _NotesMode.write
                        ? _buildEditor(context, canEditNotes)
                        : _buildPreview(context),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildCenteredMessage(
            context,
            icon: Icons.error_outline,
            title: 'Unable to load notes',
            subtitle: '$error',
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => _buildCenteredMessage(
        context,
        icon: Icons.error_outline,
        title: 'Unable to load permissions',
        subtitle: '$error',
      ),
    );
  }

  Widget _buildNotesList(
    BuildContext context,
    List<Note> notes,
    bool canAdd,
    bool canManageNotes,
  ) {
    if (notes.isEmpty && !canAdd) {
      return _buildCenteredMessage(
        context,
        icon: Icons.description_outlined,
        title: 'No notes yet',
        subtitle: 'You do not have permission to create notes.',
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: notes.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) =>
            Divider(color: Theme.of(context).dividerColor, height: 1),
        itemBuilder: (context, index) {
          if (canAdd && index == notes.length) {
            return GhostAddButton(
              label: 'New Note',
              padding: const EdgeInsets.all(12),
              borderRadius: 8,
              onTap: _createDocument,
            );
          }

          final note = notes[index];
          final preview = note.content.trim().isEmpty
              ? 'No content'
              : note.content.trim().replaceAll('\n', ' ');
          return InkWell(
            onTap: () {
              setState(() {
                _activeDocumentId = note.id;
                _currentView = _NotesView.editor;
              });
              _notifyDocumentChanged(note.id);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: ${_formatDate(note.updatedAt)}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).hintColor.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManageNotes)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: 'Delete note',
                      onPressed: () => _confirmDeleteNote(context, note, notes),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildTopRow(
    BuildContext context,
    List<Note> documents,
    Note activeDocument,
    Stream<List<NoteEditorPresence>> currentEditors,
    Set<String> connectedParticipants,
    String? currentUserId,
    bool canEditNotes,
    bool canManageNotes,
    bool canCreateNotes,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _currentView = _NotesView.list;
                _activeDocumentId = null;
              });
              _notifyDocumentChanged('');
            },
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to list',
            style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _isEditingTitle
                ? TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    onSubmitted: (_) {
                      _persistNote();
                      setState(() => _isEditingTitle = false);
                    },
                    onTapOutside: (_) {
                      _titleFocusNode.unfocus();
                      setState(() => _isEditingTitle = false);
                    },
                  )
                : InkWell(
                    onTap: canEditNotes
                        ? () {
                            setState(() => _isEditingTitle = true);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _titleFocusNode.requestFocus();
                            });
                          }
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _titleController.text.trim().isEmpty
                                  ? 'Untitled Document'
                                  : _titleController.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (canEditNotes) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Theme.of(context).hintColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          StreamBuilder<List<NoteEditorPresence>>(
            stream: currentEditors,
            builder: (context, snapshot) {
              final editors =
                  snapshot.data
                      ?.where(
                        (editor) =>
                            connectedParticipants.contains(editor.userId) ||
                            editor.userId == currentUserId,
                      )
                      .toList() ??
                  [];
              return _buildPresenceRow(context, editors);
            },
          ),
          if (canManageNotes) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () =>
                  _confirmDeleteNote(context, activeDocument, documents),
              tooltip: 'Delete document',
              icon: const Icon(Icons.delete_outline, size: 18),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeBar(BuildContext context, bool canEditNotes) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          _buildModeTab(
            context: context,
            label: 'VIEW',
            icon: Icons.visibility_outlined,
            selected: _mode == _NotesMode.preview,
            onTap: () => _setMode(_NotesMode.preview),
            enabled: true,
          ),
          if (canEditNotes)
            _buildModeTab(
              context: context,
              label: 'EDIT',
              icon: Icons.edit_outlined,
              selected: _mode == _NotesMode.write,
              onTap: () => _setMode(_NotesMode.write),
              enabled: true,
            ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final color = !enabled
        ? Theme.of(context).disabledColor
        : (selected ? activeColor : Theme.of(context).hintColor);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final actions = [
      _ToolbarAction(
        icon: Icons.format_bold,
        tooltip: 'Bold',
        onPressed: () => _wrapSelection('**', '**', placeholder: 'bold text'),
      ),
      _ToolbarAction(
        icon: Icons.format_italic,
        tooltip: 'Italic',
        onPressed: () => _wrapSelection('*', '*', placeholder: 'italic text'),
      ),
      _ToolbarAction(
        icon: Icons.strikethrough_s,
        tooltip: 'Strikethrough',
        onPressed: () => _wrapSelection('~~', '~~', placeholder: 'text'),
      ),
      _ToolbarAction(
        icon: Icons.code,
        tooltip: 'Inline code',
        onPressed: () => _wrapSelection('`', '`', placeholder: 'code'),
      ),
      _ToolbarAction(
        icon: Icons.title,
        tooltip: 'Heading 1',
        onPressed: () => _prefixSelectedLines('# '),
      ),
      _ToolbarAction(
        icon: Icons.looks_two,
        tooltip: 'Heading 2',
        onPressed: () => _prefixSelectedLines('## '),
      ),
      _ToolbarAction(
        icon: Icons.looks_3,
        tooltip: 'Heading 3',
        onPressed: () => _prefixSelectedLines('### '),
      ),
      _ToolbarAction(
        icon: Icons.format_quote,
        tooltip: 'Quote',
        onPressed: () => _prefixSelectedLines('> '),
      ),
      _ToolbarAction(
        icon: Icons.format_list_bulleted,
        tooltip: 'Bulleted list',
        onPressed: () => _prefixSelectedLines('- '),
      ),
      _ToolbarAction(
        icon: Icons.format_list_numbered,
        tooltip: 'Numbered list',
        onPressed: _numberSelectedLines,
      ),
      _ToolbarAction(
        icon: Icons.checklist,
        tooltip: 'Task list',
        onPressed: () => _prefixSelectedLines('- [ ] '),
      ),
      _ToolbarAction(
        icon: Icons.link,
        tooltip: 'Link',
        onPressed: () =>
            _wrapSelection('[', '](https://)', placeholder: 'label'),
      ),
      _ToolbarAction(
        icon: Icons.image_outlined,
        tooltip: 'Image',
        onPressed: () =>
            _insertSnippet('![alt text](https://example.com/image.png)'),
      ),
      _ToolbarAction(
        icon: Icons.table_chart_outlined,
        tooltip: 'Table',
        onPressed: () => _insertSnippet(
          '| Column 1 | Column 2 |\n| --- | --- |\n| Value | Value |',
        ),
      ),
      _ToolbarAction(
        icon: Icons.view_stream_outlined,
        tooltip: 'Horizontal rule',
        onPressed: () => _insertSnippet('\n---\n'),
      ),
      _ToolbarAction(
        icon: Icons.data_object_outlined,
        tooltip: 'Code block',
        onPressed: () =>
            _wrapSelection('```\n', '\n```', placeholder: 'code block'),
      ),
    ];

    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (_, index) {
          final action = actions[index];
          return Tooltip(
            message: action.tooltip,
            child: IconButton(
              onPressed: action.onPressed,
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).iconTheme.color,
                visualDensity: VisualDensity.compact,
                splashFactory: InkSparkle.splashFactory,
              ),
              icon: Icon(action.icon, size: 16),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemCount: actions.length,
      ),
    );
  }

  Widget _buildEditor(BuildContext context, bool canEditNotes) {
    return TextField(
      controller: _editorController,
      focusNode: _editorFocusNode,
      readOnly: !canEditNotes,
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontFamily: 'monospace',
        fontSize: 16,
        height: 1.45,
      ),
      cursorColor: Theme.of(context).colorScheme.primary,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(16),
        hintText: 'Start writing markdown...',
        hintStyle: TextStyle(color: Theme.of(context).hintColor),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: _MarkdownPreview(markdown: _editorController.text),
      ),
    );
  }

  Widget _buildPresenceRow(
    BuildContext context,
    List<NoteEditorPresence> activeEditors,
  ) {
    final labelStyle = TextStyle(
      color: Theme.of(context).hintColor,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.groups_2_outlined,
          size: 14,
          color: Theme.of(context).hintColor,
        ),
        const SizedBox(width: 6),
        Text('Editing now', style: labelStyle),
        const SizedBox(width: 8),
        if (activeEditors.isEmpty)
          Text('Nobody', style: labelStyle)
        else
          ..._buildPresenceChips(context, activeEditors),
      ],
    );
  }

  List<Widget> _buildPresenceChips(
    BuildContext context,
    List<NoteEditorPresence> editors,
  ) {
    const maxVisible = 5;
    final visible = editors.take(maxVisible).toList();
    final overflow = max(0, editors.length - maxVisible);

    final chips = <Widget>[];
    for (final editor in visible) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Tooltip(
            message: editor.displayName,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: _colorFromHex(editor.colorHex),
              child: Text(
                _initials(editor.displayName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (overflow > 0) {
      chips.add(
        CircleAvatar(
          radius: 13,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Text(
            '+$overflow',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return chips;
  }

  Widget _buildCenteredMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).hintColor, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Note? _resolveActiveDocument(List<Note> documents) {
    if (_activeDocumentId == null) return null;
    return documents.firstWhere(
      (doc) => doc.id == _activeDocumentId,
      orElse: () => documents.first,
    );
  }

  void _notifyDocumentChanged(String documentId) {
    if (widget.onDocumentChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDocumentChanged?.call(documentId);
    });
  }

  void _syncDocumentState(Note activeDocument, {bool force = false}) {
    if (_titleController.text == activeDocument.title &&
        _editorController.text == activeDocument.content) {
      _isDirty = false;
      return;
    }

    final shouldReplaceText = force || !_isDirty;
    if (!shouldReplaceText) return;

    _isApplyingDocumentState = true;
    _titleController.value = TextEditingValue(
      text: activeDocument.title,
      selection: TextSelection.collapsed(offset: activeDocument.title.length),
    );
    _editorController.value = TextEditingValue(
      text: activeDocument.content,
      selection: TextSelection.collapsed(offset: activeDocument.content.length),
    );
    _isApplyingDocumentState = false;
    _isDirty = false;
  }

  void _syncPresenceStream(String documentId) {
    if (_presenceDocumentId == documentId) return;
    _presenceDocumentId = documentId;
    _presenceStream = ref
        .read(noteRepositoryProvider)
        .watchActiveEditors(documentId);
  }

  Future<void> _confirmDeleteNote(
    BuildContext context,
    Note note,
    List<Note> documents,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          'This will remove "${note.title}". This action cannot be undone.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: dialogDestructiveButtonStyle(dialogContext),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    unawaited(_clearPresence());
    await ref.read(noteRepositoryProvider).deleteNote(note.id);

    final remaining = documents.where((doc) => doc.id != note.id).toList();
    if (remaining.isEmpty) {
      await _ensureDefaultDocument(
        ref.read(syncServiceProvider.select((s) => s.identity)) ?? 'anonymous',
      );
      if (!mounted) return;
      setState(() {
        _activeDocumentId = _defaultDocumentId;
      });
      return;
    }

    _switchDocument(remaining.first);
  }

  void _switchDocument(Note document) {
    if (_activeDocumentId == document.id) return;
    unawaited(_clearPresence());
    setState(() {
      _activeDocumentId = document.id;
    });
    widget.onDocumentChanged?.call(document.id);
    _syncDocumentState(document, force: true);
    _syncPresenceStream(document.id);
    _startPresenceHeartbeat();
  }

  Future<void> _createDocument() async {
    final userId =
        ref.read(syncServiceProvider.select((service) => service.identity)) ??
        'anonymous';
    final time = ref.read(hybridTimeServiceProvider);
    final note = Note(
      id: 'note:${_uuid.v4()}',
      title: 'Untitled Document',
      content: '',
      updatedBy: userId,
      updatedAt: time.getAdjustedTimeLocal(),
      logicalTime: time.nextLogicalTime(),
    );
    await ref.read(noteRepositoryProvider).saveNote(note);
    if (!mounted) return;
    setState(() {
      _currentView = _NotesView.editor;
    });
    _switchDocument(note);
  }

  Future<void> _ensureDefaultDocument(String userId) async {
    if (_isCreatingDefault) return;
    _isCreatingDefault = true;
    final time = ref.read(hybridTimeServiceProvider);
    final defaultNote = Note(
      id: _defaultDocumentId,
      title: 'Shared Notes',
      content: '# Shared Notes\n\nStart writing here.',
      updatedBy: userId,
      updatedAt: time.getAdjustedTimeLocal(),
      logicalTime: time.nextLogicalTime(),
    );
    await ref.read(noteRepositoryProvider).saveNote(defaultNote);
    _isCreatingDefault = false;
  }

  void _onLocalDocumentEdit() {
    if (_isApplyingDocumentState) return;
    _isDirty = true;
    _scheduleSave();
    if (_editorFocusNode.hasFocus && _mode == _NotesMode.write) {
      unawaited(_touchPresence());
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), _persistNote);
  }

  Future<void> _persistNote() async {
    final documentId = _activeDocumentId;
    if (documentId == null) return;

    final userId =
        ref.read(syncServiceProvider.select((service) => service.identity)) ??
        'anonymous';
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled Document'
        : _titleController.text.trim();

    final time = ref.read(hybridTimeServiceProvider);
    final note = Note(
      id: documentId,
      title: title,
      content: _editorController.text,
      updatedBy: userId,
      updatedAt: time.getAdjustedTimeLocal(),
      logicalTime: time.nextLogicalTime(),
    );

    await ref.read(noteRepositoryProvider).saveNote(note);
  }

  void _handleEditorFocusChanged() {
    final isEditing =
        (_editorFocusNode.hasFocus && _mode == _NotesMode.write) ||
        _titleFocusNode.hasFocus;

    if (isEditing) {
      _startPresenceHeartbeat();
    } else {
      _stopPresenceHeartbeat();
      unawaited(_clearPresence());
    }
  }

  void _setMode(_NotesMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
    });
    if (_mode == _NotesMode.preview) {
      _editorFocusNode.unfocus();
      _stopPresenceHeartbeat();
      unawaited(_clearPresence());
    } else if (_editorFocusNode.hasFocus) {
      _startPresenceHeartbeat();
    }
  }

  void _startPresenceHeartbeat() {
    final isEditing =
        (_mode == _NotesMode.write && _editorFocusNode.hasFocus) ||
        _titleFocusNode.hasFocus;

    if (!isEditing) return;
    _presenceHeartbeat?.cancel();
    unawaited(_touchPresence());
    _presenceHeartbeat = Timer.periodic(_presenceHeartbeatInterval, (_) {
      unawaited(_touchPresence());
    });
  }

  void _stopPresenceHeartbeat() {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
  }

  Future<void> _touchPresence() async {
    final documentId = _activeDocumentId;
    final userId = ref.read(
      syncServiceProvider.select((service) => service.identity),
    );
    if (documentId == null || userId == null || userId.isEmpty) return;

    final displayName =
        ref.read(identityServiceProvider).profile?.displayName ??
        _shortUserLabel(userId);

    await ref
        .read(noteRepositoryProvider)
        .touchPresence(
          documentId: documentId,
          userId: userId,
          displayName: displayName,
          colorHex: _colorForUser(userId),
          isEditing: true,
        );
  }

  Future<void> _clearPresence() async {
    final documentId = _activeDocumentId;
    final userId = ref.read(
      syncServiceProvider.select((service) => service.identity),
    );
    if (documentId == null || userId == null || userId.isEmpty) return;

    await ref
        .read(noteRepositoryProvider)
        .clearPresence(documentId: documentId, userId: userId);
  }

  void _wrapSelection(
    String prefix,
    String suffix, {
    required String placeholder,
  }) {
    final text = _editorController.text;
    var selection = _editorController.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }

    final start = selection.start;
    final end = selection.end;
    final selectedText = selection.textInside(text);
    final replacement = selectedText.isEmpty
        ? '$prefix$placeholder$suffix'
        : '$prefix$selectedText$suffix';
    _replaceText(
      text: text,
      start: start,
      end: end,
      replacement: replacement,
      cursorOffset: selectedText.isEmpty
          ? start + prefix.length + placeholder.length
          : start + replacement.length,
    );
  }

  void _insertSnippet(String snippet) {
    final text = _editorController.text;
    var selection = _editorController.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    _replaceText(
      text: text,
      start: selection.start,
      end: selection.end,
      replacement: snippet,
      cursorOffset: selection.start + snippet.length,
    );
  }

  void _prefixSelectedLines(String prefix) {
    final text = _editorController.text;
    var selection = _editorController.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    final start = selection.start;
    final end = selection.end;

    final lineStart = text.lastIndexOf('\n', max(0, start - 1)) + 1;
    final nextBreak = text.indexOf('\n', end);
    final lineEnd = nextBreak == -1 ? text.length : nextBreak;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');
    final updated = lines
        .map((line) => line.isEmpty ? line : '$prefix$line')
        .join('\n');

    _replaceText(
      text: text,
      start: lineStart,
      end: lineEnd,
      replacement: updated,
      cursorOffset: lineStart + updated.length,
    );
  }

  void _numberSelectedLines() {
    final text = _editorController.text;
    var selection = _editorController.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    final start = selection.start;
    final end = selection.end;

    final lineStart = text.lastIndexOf('\n', max(0, start - 1)) + 1;
    final nextBreak = text.indexOf('\n', end);
    final lineEnd = nextBreak == -1 ? text.length : nextBreak;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');
    var number = 1;
    final updated = lines
        .map((line) {
          if (line.trim().isEmpty) return line;
          final value = '$number. $line';
          number += 1;
          return value;
        })
        .join('\n');

    _replaceText(
      text: text,
      start: lineStart,
      end: lineEnd,
      replacement: updated,
      cursorOffset: lineStart + updated.length,
    );
  }

  void _replaceText({
    required String text,
    required int start,
    required int end,
    required String replacement,
    required int cursorOffset,
  }) {
    final nextText = text.replaceRange(start, end, replacement);
    _editorController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: cursorOffset.clamp(0, nextText.length).toInt(),
      ),
    );
  }

  String _colorForUser(String userId) {
    const palette = [
      '#3B82F6',
      '#06B6D4',
      '#10B981',
      '#F59E0B',
      '#EF4444',
      '#6366F1',
      '#F97316',
      '#14B8A6',
    ];
    final hash = userId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[hash % palette.length];
  }

  Color _colorFromHex(String value) {
    final hex = value.replaceAll('#', '');
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return const Color(0xFF64748B);
    if (hex.length <= 6) return Color(0xFF000000 | parsed);
    return Color(parsed);
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _shortUserLabel(String userId) {
    if (userId.length <= 8) return userId;
    return '${userId.substring(0, 4)}...${userId.substring(userId.length - 3)}';
  }
}

class _ToolbarAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
}

class _MarkdownPreview extends StatelessWidget {
  final String markdown;

  const _MarkdownPreview({required this.markdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.hintColor;
    final divider = theme.dividerColor;
    final primary = theme.colorScheme.primary;
    final panel = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.24,
    );

    final h1 = (theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
      color: onSurface,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final h2 = (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      color: onSurface,
      fontWeight: FontWeight.w700,
      height: 1.28,
    );
    final h3 = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      color: onSurface,
      fontWeight: FontWeight.w700,
      height: 1.32,
    );
    final paragraph = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: onSurface, fontSize: 15, height: 1.4);
    final codeText = paragraph.copyWith(fontFamily: 'monospace');

    final lines = markdown.split('\n');
    final widgets = <Widget>[];
    var inCodeBlock = false;
    final codeBuffer = <String>[];

    void flushCodeBlock() {
      if (codeBuffer.isEmpty) return;
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: divider),
          ),
          child: SelectableText(
            codeBuffer.join('\n'),
            style: codeText.copyWith(height: 1.35),
          ),
        ),
      );
      codeBuffer.clear();
    }

    int i = 0;
    while (i < lines.length) {
      final rawLine = lines[i];
      final line = rawLine.trimRight();
      if (line.startsWith('```')) {
        if (inCodeBlock) {
          flushCodeBlock();
        }
        inCodeBlock = !inCodeBlock;
        i += 1;
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.add(rawLine);
        i += 1;
        continue;
      }

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        i += 1;
        continue;
      }

      if (line == '---' || line == '***') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: divider, height: 1),
          ),
        );
        i += 1;
        continue;
      }

      if (line.startsWith('# ')) {
        widgets.add(
          _lineText(
            _parseInline(context, line.substring(2), const TextStyle()),
            h1,
          ),
        );
        i += 1;
        continue;
      }

      if (line.startsWith('## ')) {
        widgets.add(
          _lineText(
            _parseInline(context, line.substring(3), const TextStyle()),
            h2,
          ),
        );
        i += 1;
        continue;
      }

      if (line.startsWith('### ')) {
        widgets.add(
          _lineText(
            _parseInline(context, line.substring(4), const TextStyle()),
            h3,
          ),
        );
        i += 1;
        continue;
      }

      if (line.startsWith('> ')) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: primary, width: 3)),
            ),
            child: _lineText(
              _parseInline(context, line.substring(2), const TextStyle()),
              paragraph,
            ),
          ),
        );
        i += 1;
        continue;
      }

      if (_looksLikeTableHeader(line) &&
          i + 1 < lines.length &&
          _isTableSeparator(lines[i + 1])) {
        final header = _splitTableRow(line);
        i += 2;
        final rows = <List<String>>[];
        while (i < lines.length && _looksLikeTableRow(lines[i])) {
          rows.add(_splitTableRow(lines[i]));
          i += 1;
        }
        widgets.add(
          _buildTable(context, header, rows, divider, panel, onSurface, muted),
        );
        continue;
      }

      final taskMatch = RegExp(r'^- \[(x|X| )\] (.*)$').firstMatch(line);
      if (taskMatch != null) {
        final checked = taskMatch.group(1)!.toLowerCase() == 'x';
        final text = taskMatch.group(2) ?? '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  checked
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: checked
                      ? Theme.of(context).colorScheme.primary
                      : muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _lineText(
                    _parseInline(context, text, const TextStyle()),
                    TextStyle(
                      color: checked ? muted : onSurface,
                      fontSize: 15,
                      decoration: checked ? TextDecoration.lineThrough : null,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i += 1;
        continue;
      }

      final orderedMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
      if (orderedMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${orderedMatch.group(1)}.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _lineText(
                    _parseInline(
                      context,
                      orderedMatch.group(2) ?? '',
                      const TextStyle(),
                    ),
                    paragraph.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        );
        i += 1;
        continue;
      }

      if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _lineText(
                    _parseInline(context, line.substring(2), const TextStyle()),
                    paragraph.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        );
        i += 1;
        continue;
      }

      widgets.add(
        _lineText(_parseInline(context, line, const TextStyle()), paragraph),
      );
      i += 1;
    }

    flushCodeBlock();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _lineText(List<InlineSpan> spans, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText.rich(TextSpan(style: style, children: spans)),
    );
  }

  bool _looksLikeTableHeader(String line) {
    if (!line.contains('|')) return false;
    return line.trim().length > 1;
  }

  bool _looksLikeTableRow(String line) {
    if (!line.contains('|')) return false;
    return line.trim().length > 1;
  }

  bool _isTableSeparator(String line) {
    final trimmed = line.trim();
    final separatorPattern = RegExp(
      r'^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$',
    );
    return separatorPattern.hasMatch(trimmed);
  }

  List<String> _splitTableRow(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.endsWith('|')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.split('|').map((cell) => cell.trim()).toList();
  }

  Widget _buildTable(
    BuildContext context,
    List<String> header,
    List<List<String>> rows,
    Color divider,
    Color panel,
    Color onSurface,
    Color muted,
  ) {
    final columnCount = header.length;
    final normalizedRows = rows
        .map((row) => _padRow(row, columnCount))
        .toList();

    final headerStyle =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
          color: onSurface,
        );
    final cellStyle =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontSize: 13,
          color: onSurface,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          columnWidths: {
            for (int i = 0; i < columnCount; i++) i: const FlexColumnWidth(1),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: divider),
            verticalInside: BorderSide(color: divider),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: panel.withValues(alpha: 0.6)),
              children: header
                  .map(
                    (cell) => Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(cell, style: headerStyle),
                    ),
                  )
                  .toList(),
            ),
            ...normalizedRows.map(
              (row) => TableRow(
                children: row
                    .map(
                      (cell) => Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(cell, style: cellStyle),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (normalizedRows.isEmpty)
              TableRow(
                children: header
                    .map(
                      (_) => Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text('—', style: TextStyle(color: muted)),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _padRow(List<String> row, int length) {
    if (row.length >= length) return row.sublist(0, length);
    return [...row, ...List.filled(length - row.length, '')];
  }

  List<InlineSpan> _parseInline(
    BuildContext context,
    String text,
    TextStyle baseStyle,
  ) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*|`[^`]+`|~~[^~]+~~|\*[^*]+\*|\[[^\]]+\]\([^)]+\))',
    );

    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('*') && token.endsWith('*')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith('~~') && token.endsWith('~~')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (token.startsWith('`') && token.endsWith('`')) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                token.substring(1, token.length - 1),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        );
      } else if (token.startsWith('[') && token.contains('](')) {
        final split = token.indexOf('](');
        final label = token.substring(1, split);
        spans.add(
          TextSpan(
            text: label,
            style: baseStyle.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token));
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }
}
