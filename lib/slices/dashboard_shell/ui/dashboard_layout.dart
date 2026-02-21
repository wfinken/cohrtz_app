import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';

import '../../../app/di/app_providers.dart';
import '../state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/tasks/ui/widgets/tasks_widget.dart';
import 'package:cohortz/slices/vault/ui/widgets/vault_widget.dart';
import 'package:cohortz/slices/chat/ui/widgets/chat_accordion.dart';
import 'package:cohortz/slices/chat/ui/widgets/chat_widget.dart';
import 'widgets/group_selection_rail.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/group_drawer.dart';
import 'package:cohortz/slices/polls/ui/widgets/polls_widget.dart';
import 'dashboard_edit_notifier.dart';
import 'controllers/dashboard_shell_controller.dart';
import 'widgets/dashboard_grid_view.dart';
import '../../../shared/theme/tokens/layout_constants.dart';
import 'widgets/widget_alerts_button.dart';

import 'package:cohortz/slices/calendar/ui/dialogs/add_event_dialog.dart';
import 'package:cohortz/slices/vault/ui/dialogs/add_vault_dialog.dart';
import 'package:cohortz/slices/tasks/ui/dialogs/add_task_dialog.dart';
import 'package:cohortz/slices/polls/ui/dialogs/create_poll_dialog.dart';
import 'dialogs/onboarding_dialog.dart';
import 'package:cohortz/slices/members/ui/dialogs/invite_dialog.dart';
import 'package:cohortz/slices/calendar/ui/pages/calendar_page.dart';
import 'package:cohortz/slices/members/ui/pages/members_page.dart';
import 'package:cohortz/slices/notes/ui/pages/notes_page.dart';

class DashboardLayout extends ConsumerStatefulWidget {
  const DashboardLayout({super.key});

  @override
  ConsumerState<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends ConsumerState<DashboardLayout> {
  final _shellController = DashboardShellController();
  bool _isDrawerOpen = false;
  bool _isChatAccordionOpen = false;
  DashboardView _currentView = DashboardView.dashboard;
  String? _selectedNoteId;
  late final ProviderSubscription<String?> _activeRoomSubscription;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _activeRoomSubscription = ref.listenManual(
      syncServiceProvider.select((s) => s.currentRoomName),
      (previous, next) {
        if (next != null && next.isNotEmpty && previous != next) {
          final identityService = ref.read(identityServiceProvider);
          final userProfile = identityService.profile;
          if (userProfile != null) {
            ref.read(dashboardRepositoryProvider).saveUserProfile(userProfile);
          }

          if (!mounted) return;
          setState(() {
            _currentView = DashboardView.dashboard;
            _selectedNoteId = null;
            _isDrawerOpen = false;
            _isChatAccordionOpen = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _activeRoomSubscription.close();
    super.dispose();
  }

  void _checkOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final identityService = ref.read(identityServiceProvider);
      if (identityService.isNew) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const OnboardingDialog(),
        );
      }
    });
  }

  int _calculateLayoutIdentifier(double width) {
    if (width < 500) return 1; // Mobile
    if (width < 900) return 2; // Compact (New)
    return 12; // Desktop
  }

  int _calculateGridColumns(double width) {
    if (width < 500) return 1; // Mobile
    if (width < 900) return 2; // Compact (New)
    return 12; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncServiceStateProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileLayout = screenWidth < 900;
    final currentRoomName = syncState.currentRoomName;
    final isConnected = syncState.isConnected;
    final knownGroups = syncState.knownGroups;
    final isActiveRoomConnected = syncState.isActiveRoomConnected;
    final canShowDrawer = knownGroups.isNotEmpty && isActiveRoomConnected;
    final drawerOpen = _isDrawerOpen && canShowDrawer;
    final showInlineDrawer = !isMobileLayout && drawerOpen;
    final showOverlayDrawer = isMobileLayout && drawerOpen;
    final overlayDrawerWidth = (screenWidth - 72).clamp(0.0, 320.0).toDouble();
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    bool canView(int flag) {
      return permissionsAsync.maybeWhen(
        data: (permissions) => PermissionUtils.has(permissions, flag),
        orElse: () => true,
      );
    }

    final canViewVault = canView(PermissionFlags.viewVault);
    final canViewCalendar = canView(PermissionFlags.viewCalendar);
    final canViewTasks = canView(PermissionFlags.viewTasks);
    final canViewNotes = canView(PermissionFlags.viewNotes);
    final canViewMembers = canView(PermissionFlags.viewMembers);
    final canViewChat = canView(PermissionFlags.viewChat);
    final canViewPolls = canView(PermissionFlags.viewPolls);
    final effectiveCurrentView = _shellController.coerceViewByPermissions(
      _currentView,
      canViewVault: canViewVault,
      canViewCalendar: canViewCalendar,
      canViewTasks: canViewTasks,
      canViewNotes: canViewNotes,
      canViewMembers: canViewMembers,
      canViewChat: canViewChat,
      canViewPolls: canViewPolls,
    );

    final groupSettingsAsync = ref.watch(groupSettingsProvider);
    final groupSettings = groupSettingsAsync.value;

    final syncService = ref.watch(syncServiceProvider);
    final groupName =
        groupSettings?.name ?? syncService.getFriendlyName(currentRoomName);
    final groupType = groupSettings?.groupType ?? GroupType.family;
    final isEditing = ref.watch(dashboardEditProvider).isEditing;

    final hasAvailableGroups = knownGroups.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          GroupSelectionRail(
            activeGroupId: currentRoomName,
            onGroupSelected: (groupId) {
              setState(() {
                _currentView = DashboardView.dashboard;
                _selectedNoteId = null;
                if (isMobileLayout) {
                  _isDrawerOpen = false;
                }
                _isChatAccordionOpen = false;
              });
            },
            onToggleDrawer: () {
              if (!canShowDrawer) return;
              setState(() {
                _isDrawerOpen = !_isDrawerOpen;
              });
            },
            isDrawerOpen: drawerOpen,
          ),
          if (showInlineDrawer)
            GroupDrawer(
              groupName: groupName,
              currentView: effectiveCurrentView,
              onViewChanged: (view) {
                setState(() {
                  _currentView = view;
                  if (view == DashboardView.dashboard) {
                    _isChatAccordionOpen = false;
                  }
                });
              },
            ),
          Expanded(
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: DashboardAppBar(
                    title: groupName,
                    isEditing: isEditing,
                    isDashboardView:
                        effectiveCurrentView == DashboardView.dashboard,
                    onActiveGroupChanged: (groupId) {},
                  ),
                  floatingActionButton: _buildFloatingActionButton(
                    effectiveCurrentView,
                  ),
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      (canViewChat &&
                                          effectiveCurrentView !=
                                              DashboardView.channels)
                                      ? LayoutConstants.chatAccordionTotalHeight
                                      : 0,
                                ),
                                child: _buildBodyContent(
                                  isConnected,
                                  hasAvailableGroups,
                                  _calculateLayoutIdentifier(
                                    constraints.maxWidth,
                                  ),
                                  _calculateGridColumns(constraints.maxWidth),
                                  groupType,
                                  isEditing,
                                  constraints.maxWidth,
                                  effectiveCurrentView,
                                  {
                                    'vault': canViewVault,
                                    'calendar': canViewCalendar,
                                    'tasks': canViewTasks,
                                    'notes': canViewNotes,
                                    'users': canViewMembers,
                                    'chat': canViewChat,
                                    'polls': canViewPolls,
                                  },
                                ),
                              );
                            },
                          ),
                          if (canViewChat &&
                              effectiveCurrentView != DashboardView.channels)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: ChatAccordion(
                                groupName: groupName,
                                isOpen: _isChatAccordionOpen,
                                onToggle: () {
                                  setState(() {
                                    _isChatAccordionOpen =
                                        !_isChatAccordionOpen;
                                  });
                                },
                                onOpenPage: () {
                                  setState(() {
                                    _currentView = DashboardView.channels;
                                    _selectedNoteId = null;
                                  });
                                },
                                maxHeight: constraints.maxHeight,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (showOverlayDrawer)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _isDrawerOpen = false),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                if (showOverlayDrawer)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: SizedBox(
                      width: overlayDrawerWidth,
                      child: Material(
                        elevation: 10,
                        child: GroupDrawer(
                          groupName: groupName,
                          currentView: effectiveCurrentView,
                          onViewChanged: (view) {
                            setState(() {
                              _currentView = view;
                              if (view == DashboardView.dashboard) {
                                _isChatAccordionOpen = false;
                              }
                            });
                          },
                          onItemSelected: () {
                            if (!_isDrawerOpen) return;
                            setState(() => _isDrawerOpen = false);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(
    bool isConnected,
    bool hasAvailableGroups,
    int layoutIdentifier,
    int gridColumns,
    GroupType groupType,
    bool isEditing,
    double width,
    DashboardView currentView,
    Map<String, bool> viewPermissions,
  ) {
    if (!hasAvailableGroups || !isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'No groups!',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Join a group to start collaborating.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    switch (currentView) {
      case DashboardView.dashboard:
        return _buildDashboardView(
          layoutIdentifier,
          gridColumns,
          groupType,
          isEditing,
          width,
          viewPermissions,
        );

      case DashboardView.channels:
        return _buildWidgetPage(
          title: 'Channels',
          widgetType: 'chat',
          icon: Icons.chat_bubble_outline,
          iconColor: colorScheme.primary,
          child: ChatWidget(isFullPage: true, isAccordion: false),
        );

      case DashboardView.vault:
        return _buildWidgetPage(
          title: groupType.vaultTitle,
          widgetType: 'vault',
          icon: Icons.security,
          iconColor: colorScheme.tertiary,
          child: const Padding(
            padding: EdgeInsets.all(24.0),
            child: VaultWidget(),
          ),
        );
      case DashboardView.calendar:
        return _buildWidgetPage(
          title: groupType.calendarTitle,
          widgetType: 'calendar',
          icon: Icons.calendar_today,
          iconColor: colorScheme.secondary,
          child: const CalendarPage(),
        );
      case DashboardView.tasks:
        return _buildWidgetPage(
          title: groupType.tasksTitle,
          widgetType: 'tasks',
          icon: Icons.checklist,
          iconColor: colorScheme.primary,
          child: const Padding(
            padding: EdgeInsets.all(24.0),
            child: TasksWidget(),
          ),
        );
      case DashboardView.notes:
        return _buildWidgetPage(
          title: 'Notes',
          widgetType: 'notes',
          icon: Icons.description_outlined,
          iconColor: colorScheme.secondary,
          child: NotesPage(
            initialDocumentId: _selectedNoteId,
            onDocumentChanged: (documentId) {
              if (_selectedNoteId == documentId) return;
              setState(() {
                _selectedNoteId = documentId;
              });
            },
          ),
        );
      case DashboardView.members:
        return _buildWidgetPage(
          title: 'Members',
          widgetType: 'users',
          icon: Icons.people,
          iconColor: colorScheme.tertiary,
          child: const MembersPage(),
        );
      case DashboardView.polls:
        return _buildWidgetPage(
          title: 'Polls',
          widgetType: 'polls',
          icon: Icons.bar_chart,
          iconColor: colorScheme.primary,
          child: const Padding(
            padding: EdgeInsets.all(24.0),
            child: PollsWidget(),
          ),
        );
    }
  }

  Widget _buildWidgetPage({
    required String title,
    required String widgetType,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    final groupId =
        ref.watch(syncServiceProvider.select((s) => s.currentRoomName)) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentView = DashboardView.dashboard;
                    _selectedNoteId = null;
                    _isChatAccordionOpen = false;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Dashboard',
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              WidgetAlertsButton(
                groupId: groupId,
                widgetType: widgetType,
                widgetTitle: title,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildDashboardView(
    int layoutIdentifier,
    int gridColumns,
    GroupType groupType,
    bool isEditing,
    double width,
    Map<String, bool> viewPermissions,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final widgetsAsync = ref.watch(
          dashboardWidgetsProvider((
            groupId:
                ref.watch(dashboardRepositoryProvider).currentRoomName ?? '',
            columns: layoutIdentifier,
          )),
        );

        return widgetsAsync.when(
          data: (data) {
            final filteredWidgets = data.widgets.where((widget) {
              final canView = viewPermissions[widget.type];
              if (widget.type == 'chat') return false;
              return canView != false;
            }).toList();
            return DashboardGridView(
              widgets: filteredWidgets,
              requiresScaling: data.requiresScaling,
              width: width,
              groupType: groupType,
              isEditing: isEditing,
              columns: gridColumns,
              layoutIdentifier: layoutIdentifier,

              onOpenWidget: _openWidgetView,
              onOpenNote: (noteId) {
                setState(() {
                  _selectedNoteId = noteId;
                  _currentView = DashboardView.notes;
                });
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context, String type) async {
    final permissions = await ref.read(currentUserPermissionsProvider.future);
    if (!context.mounted) return;
    bool allowed = true;
    String? denialMessage;

    switch (type) {
      case 'calendar':
        allowed = PermissionUtils.has(
          permissions,
          PermissionFlags.editCalendar,
        );
        denialMessage = 'You do not have permission to create events.';
        break;
      case 'vault':
        allowed = PermissionUtils.has(permissions, PermissionFlags.editVault);
        denialMessage = 'You do not have permission to add vault items.';
        break;
      case 'tasks':
        allowed = PermissionUtils.has(permissions, PermissionFlags.editTasks);
        denialMessage = 'You do not have permission to create tasks.';
        break;
      case 'polls':
        allowed = PermissionUtils.has(permissions, PermissionFlags.editPolls);
        denialMessage = 'You do not have permission to create polls.';
        break;
      case 'users':
        allowed = PermissionUtils.has(
          permissions,
          PermissionFlags.manageInvites,
        );
        denialMessage = 'You do not have permission to manage invites.';
        break;
    }

    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(denialMessage ?? 'Permission denied.')),
      );
      return;
    }

    switch (type) {
      case 'calendar':
        showDialog(context: context, builder: (_) => const AddEventDialog());
        break;
      case 'vault':
        showDialog(context: context, builder: (_) => const AddVaultDialog());
        break;
      case 'tasks':
        showDialog(context: context, builder: (_) => const AddTaskDialog());
        break;
      case 'polls':
        showDialog(context: context, builder: (_) => const CreatePollDialog());
        break;
      case 'users':
        showDialog(context: context, builder: (_) => const InviteDialog());
        break;
      case 'notes':
        setState(() => _currentView = DashboardView.notes);
        break;
    }
  }

  void _openWidgetView(String type) {
    DashboardView? nextView;
    switch (type) {
      case 'vault':
        nextView = DashboardView.vault;
        break;
      case 'calendar':
        nextView = DashboardView.calendar;
        break;
      case 'tasks':
        nextView = DashboardView.tasks;
        break;
      case 'notes':
        nextView = DashboardView.notes;
        break;
      case 'users':
        nextView = DashboardView.members;
        break;
      case 'polls':
        nextView = DashboardView.polls;
        break;
    }
    if (nextView == null) return;
    setState(() {
      if (nextView != DashboardView.notes) {
        _selectedNoteId = null;
      }
      _currentView = nextView!;
    });
  }

  Widget? _buildFloatingActionButton(DashboardView currentView) {
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final canViewVault = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.viewVault),
      orElse: () => true,
    );
    final canEditVault = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editVault),
      orElse: () => false,
    );
    final canEditTasks = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editTasks),
      orElse: () => false,
    );
    final canEditPolls = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editPolls),
      orElse: () => false,
    );
    final canManageInvites = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageInvites),
      orElse: () => false,
    );

    final fab = _buildFab(
      currentView,
      canEditTasks,
      canViewVault,
      canEditVault,
      canEditPolls,
      canManageInvites,
    );
    if (fab == null) return null;

    final canViewChat = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.viewChat),
      orElse: () => true,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: (canViewChat && currentView != DashboardView.channels)
            ? LayoutConstants.chatAccordionTotalHeight
            : 0,
      ),
      child: fab,
    );
  }

  Widget? _buildFab(
    DashboardView currentView,
    bool canEditTasks,
    bool canViewVault,
    bool canEditVault,
    bool canEditPolls,
    bool canManageInvites,
  ) {
    switch (currentView) {
      case DashboardView.channels:
        return null;
      case DashboardView.tasks:
        if (!canEditTasks) return null;
        return FloatingActionButton(
          onPressed: () => _showAddDialog(context, 'tasks'),
          tooltip: 'Add Task',
          child: const Icon(Icons.add),
        );
      case DashboardView.vault:
        if (!canViewVault || !canEditVault) return null;
        return FloatingActionButton(
          onPressed: () => _showAddDialog(context, 'vault'),
          tooltip: 'Add Vault Item',
          child: const Icon(Icons.add),
        );
      case DashboardView.polls:
        if (!canEditPolls) return null;
        return FloatingActionButton(
          onPressed: () => _showAddDialog(context, 'polls'),
          tooltip: 'Create Poll',
          child: const Icon(Icons.add),
        );
      case DashboardView.calendar:
        return null;
      case DashboardView.members:
        if (!canManageInvites) return null;
        return FloatingActionButton(
          onPressed: () => _showAddDialog(context, 'users'),
          tooltip: 'Invite Members',
          child: const Icon(Icons.person_add),
        );
      case DashboardView.notes:
      case DashboardView.dashboard:
        return null;
    }
  }
}
