import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/app_providers.dart';

import 'connection_views/connection_create_view.dart';
import 'connection_views/connection_initial_view.dart';
import 'connection_views/connection_join_view.dart';
import 'connection_views/connection_profile_view.dart';

enum _ConnectionView { initial, create, join, profile }

/// A dialog that manages the group connection flow.
///
/// It orchestrates three views:
/// 1. [ConnectionInitialView] - Choose to Create or Join.
/// 2. [ConnectionCreateView] - Create a new group.
/// 3. [ConnectionJoinView] - Join an existing group (with OTP).
///
/// State management for the views is handled here (switching views),
/// while specific logic is delegated to the view widgets.
class ConnectionDialog extends ConsumerStatefulWidget {
  const ConnectionDialog({super.key});

  @override
  ConsumerState<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends ConsumerState<ConnectionDialog> {
  _ConnectionView _currentView = _ConnectionView.initial;
  _ConnectionView _profileBackTarget = _ConnectionView.initial;
  String _pendingRoomName = '';
  String _pendingInviteCode = '';
  String _initialProfileName = '';

  @override
  Widget build(BuildContext context) {
    switch (_currentView) {
      case _ConnectionView.initial:
        return ConnectionInitialView(
          onCreateSelected: () =>
              setState(() => _currentView = _ConnectionView.create),
          onJoinSelected: () =>
              setState(() => _currentView = _ConnectionView.join),
        );
      case _ConnectionView.create:
        return ConnectionCreateView(
          onBack: () => setState(() => _currentView = _ConnectionView.initial),
          onCreate: (name) => _moveToProfileStep(
            roomName: name,
            backTarget: _ConnectionView.create,
          ),
        );
      case _ConnectionView.join:
        return ConnectionJoinView(
          onBack: () => setState(() => _currentView = _ConnectionView.initial),
          onJoin: (name, code) => _moveToProfileStep(
            roomName: name,
            inviteCode: code,
            backTarget: _ConnectionView.join,
          ),
        );
      case _ConnectionView.profile:
        return ConnectionProfileView(
          groupName: _pendingRoomName,
          initialDisplayName: _initialProfileName,
          submitLabel: _pendingInviteCode.isEmpty
              ? 'Create Group'
              : 'Join Group',
          onBack: () => setState(() => _currentView = _profileBackTarget),
          onContinue: (displayName) => _handleConnection(
            _pendingRoomName,
            inviteCode: _pendingInviteCode,
            localDisplayName: displayName,
          ),
        );
    }
  }

  Future<void> _moveToProfileStep({
    required String roomName,
    required _ConnectionView backTarget,
    String inviteCode = '',
  }) async {
    final trimmedRoomName = roomName.trim();
    if (trimmedRoomName.isEmpty) return;

    final identityService = ref.read(groupIdentityServiceProvider);
    final existing = await identityService.loadForGroup(trimmedRoomName);
    if (!mounted) return;

    setState(() {
      _pendingRoomName = trimmedRoomName;
      _pendingInviteCode = inviteCode;
      _initialProfileName = existing?.displayName ?? '';
      _profileBackTarget = backTarget;
      _currentView = _ConnectionView.profile;
    });
  }

  Future<void> _handleConnection(
    String roomName, {
    String inviteCode = "",
    required String localDisplayName,
  }) async {
    if (roomName.trim().isEmpty || localDisplayName.trim().isEmpty) return;

    // Close the dialog immediately.
    // The global ConnectionStatusModal (in HomeScreen) will handle the UI
    // for progress and errors.
    Navigator.of(context).pop();

    final connectionProcess = ref.read(groupConnectionProcessProvider);

    try {
      await connectionProcess.connect(
        roomName,
        inviteCode: inviteCode,
        localDisplayName: localDisplayName,
      );
    } catch (e) {
      // Error is already reported to GroupConnectionStatusNotifier by the process,
      // which updates the ConnectionStatusModal.
      // We just log it here for sanity.
      debugPrint('[ConnectionDialog] Connection failed: $e');
    }
  }
}
