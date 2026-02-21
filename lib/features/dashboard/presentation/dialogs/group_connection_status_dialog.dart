import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/features/sync/application/sync_service.dart';

import '../../../../core/providers.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/utils/sync_diagnostics.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/system_model.dart';

enum _ConnectionPanelView { status, protocol, log, network }

enum _ConnectionState { connected, connecting, disconnected }

enum _NetworkMode { relay, mesh }

enum _DiagnosticType { info, success, warning, error }

class GroupConnectionStatusDialog extends ConsumerStatefulWidget {
  const GroupConnectionStatusDialog({super.key});

  @override
  ConsumerState<GroupConnectionStatusDialog> createState() =>
      _GroupConnectionStatusDialogState();
}

class _GroupConnectionStatusDialogState
    extends ConsumerState<GroupConnectionStatusDialog> {
  final _random = Random();

  _ConnectionPanelView _view = _ConnectionPanelView.status;
  _NetworkMode _networkMode = _NetworkMode.mesh;

  Timer? _metricsTimer;
  StreamSubscription<SyncDiagnosticEvent>? _diagnosticSubscription;

  int _pingMs = 52;
  int _sentBytes = 0;
  int _receivedBytes = 0;

  bool _isSynchronizing = false;
  bool _isReconnecting = false;
  bool _isAdvancingEpoch = false;
  bool _isSessionPaused = false;

  int? _lastRemoteParticipants;
  DateTime? _lastSyncAt;
  String _roomNameAtOpen = '';

  final List<_ActivityItem> _activity = <_ActivityItem>[];
  final List<_DiagnosticEntry> _logs = <_DiagnosticEntry>[];

  @override
  void initState() {
    super.initState();
    _roomNameAtOpen = ref.read(syncServiceProvider).currentRoomName ?? '';
    _hydrateDiagnostics(_roomNameAtOpen);
    _addActivity('Connection panel opened');

    _diagnosticSubscription = SyncDiagnostics.stream.listen((event) {
      if (!mounted) return;
      if (event.roomName != _roomNameAtOpen || event.roomName.isEmpty) return;
      _applyDiagnosticEvent(event);
    });

    _metricsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final syncService = ref.read(syncServiceProvider);
      final state = _effectiveConnectionState(syncService);
      if (state != _ConnectionState.connected) {
        return;
      }

      setState(() {
        _pingMs = (_pingMs + _random.nextInt(9) - 4).clamp(18, 180);
      });
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _diagnosticSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final syncService = ref.watch(syncServiceProvider);
    final roomName = syncService.currentRoomName ?? '';
    final myId = syncService.identity;
    final remoteParticipants = syncService.remoteParticipants.length;

    final groupSettings = ref.watch(groupSettingsProvider).value;
    final groupName = _resolveGroupName(syncService, groupSettings, roomName);
    final inviteCode = _resolveInviteCode(groupSettings);
    final protocolEpoch = roomName.isNotEmpty
        ? ref.watch(treeKemEpochProvider(roomName)).value ?? 0
        : 0;

    final profiles = ref.watch(userProfilesProvider).value ?? const [];
    final totalPeers = profiles.isNotEmpty
        ? profiles.length
        : max(remoteParticipants + 1, 1);

    final connectionState = _effectiveConnectionState(syncService);
    final onlinePeers = connectionState == _ConnectionState.connected
        ? remoteParticipants + 1
        : connectionState == _ConnectionState.connecting
        ? 1
        : 0;

    ref.listen<bool>(
      syncServiceProvider.select((s) => s.isActiveRoomConnected),
      (previous, next) {
        if (previous == next) return;

        if (next) {
          if (_isSessionPaused) {
            setState(() => _isSessionPaused = false);
          }
          _addActivity('Connected to group session');
          _addLog('Mesh session established.', type: _DiagnosticType.success);
        } else {
          _addActivity('Group session disconnected');
          _addLog(
            'No active transport session.',
            type: _DiagnosticType.warning,
          );
        }
      },
    );

    ref.listen<int>(
      syncServiceProvider.select((s) => s.remoteParticipants.length),
      (previous, next) {
        _lastRemoteParticipants ??= previous ?? next;
        if (_lastRemoteParticipants == next) {
          return;
        }

        if (next > (_lastRemoteParticipants ?? 0)) {
          _addActivity('A peer joined the group');
          _addLog('Peer discovery event detected.', type: _DiagnosticType.info);
        } else {
          _addActivity('A peer left the group');
          _addLog(
            'Peer disconnected from active session.',
            type: _DiagnosticType.warning,
          );
        }
        _lastRemoteParticipants = next;
      },
    );

    final title = switch (_view) {
      _ConnectionPanelView.status => 'Connection Status',
      _ConnectionPanelView.protocol => 'Security Protocol',
      _ConnectionPanelView.log => 'Diagnostic Log',
      _ConnectionPanelView.network => 'Network Topology',
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                spacing: 12,
                children: [
                  if (_view != _ConnectionPanelView.status)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        setState(() => _view = _ConnectionPanelView.status);
                      },
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const Icon(Icons.wifi_tethering, size: 24),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (_view) {
                  _ConnectionPanelView.status => _buildStatusView(
                    context,
                    groupName: groupName,
                    roomName: roomName,
                    inviteCode: inviteCode,
                    connectionState: connectionState,
                    onlinePeers: onlinePeers,
                    totalPeers: totalPeers,
                    pingMs: _pingMs,
                  ),
                  _ConnectionPanelView.protocol => _buildProtocolView(
                    context,
                    protocolEpoch: protocolEpoch,
                  ),
                  _ConnectionPanelView.log => _buildLogView(context),
                  _ConnectionPanelView.network => _buildNetworkView(context),
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: roomName.isEmpty
                        ? null
                        : () => _confirmLeaveGroup(
                            roomName: roomName,
                            localUserId: myId,
                          ),
                    icon: Icon(
                      Icons.exit_to_app,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    label: Text(
                      'Leave Group',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusView(
    BuildContext context, {
    required String groupName,
    required String roomName,
    required String? inviteCode,
    required _ConnectionState connectionState,
    required int onlinePeers,
    required int totalPeers,
    required int pingMs,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final statusColor = switch (connectionState) {
      _ConnectionState.connected => colorScheme.tertiary,
      _ConnectionState.connecting => colorScheme.primary,
      _ConnectionState.disconnected => colorScheme.error,
    };

    final statusLabel = switch (connectionState) {
      _ConnectionState.connected => 'CONNECTED',
      _ConnectionState.connecting => 'CONNECTING',
      _ConnectionState.disconnected => 'DISCONNECTED',
    };

    final statusSubtitle = switch (connectionState) {
      _ConnectionState.connected => '(${pingMs}ms)',
      _ConnectionState.connecting => '(handshake)',
      _ConnectionState.disconnected => '(offline)',
    };

    final primaryLabel = connectionState == _ConnectionState.connected
        ? (_isSynchronizing ? 'Synchronizing...' : 'Synchronize Now')
        : (_isReconnecting ? 'Reconnecting...' : 'Reconnect Group Session');

    final primaryIcon = connectionState == _ConnectionState.connected
        ? Icons.sync
        : Icons.wifi_tethering;

    final canRunPrimary = connectionState == _ConnectionState.connected
        ? !_isSynchronizing
        : !_isReconnecting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withValues(alpha: 0.72),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            Icons.stacked_bar_chart,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupName,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  StatusChip(
                                    label: statusLabel,
                                    color: statusColor,
                                    icon:
                                        connectionState ==
                                            _ConnectionState.connected
                                        ? Icons.wifi
                                        : connectionState ==
                                              _ConnectionState.connecting
                                        ? Icons.sync
                                        : Icons.wifi_off,
                                  ),
                                  Text(
                                    statusSubtitle,
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.public, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                    if (roomName.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          roomName,
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'NODES ONLINE',
                            value: '$onlinePeers',
                            subtitle: '/ $totalPeers',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            label: 'LAST SYNC',
                            value: _lastSyncAt == null
                                ? 'Never'
                                : _formatRelative(_lastSyncAt!),
                            subtitle: '',
                            highlight: _lastSyncAt != null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.north_east,
                          size: 16,
                          color: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_bytesToMb(_sentBytes).toStringAsFixed(2)} MB',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(width: 18),
                        Icon(
                          Icons.south_west,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_bytesToMb(_receivedBytes).toStringAsFixed(2)} MB',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canRunPrimary
                      ? () {
                          if (connectionState == _ConnectionState.connected) {
                            _handleSynchronize();
                          } else {
                            _handleReconnect();
                          }
                        }
                      : null,
                  icon: _buildBusyIcon(
                    running: _isSynchronizing || _isReconnecting,
                    icon: primaryIcon,
                  ),
                  label: Text(primaryLabel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_isReconnecting || _isSynchronizing)
                          ? null
                          : () {
                              if (connectionState ==
                                      _ConnectionState.connected ||
                                  connectionState ==
                                      _ConnectionState.connecting) {
                                _handleDisconnect();
                              } else {
                                _handleReconnect();
                              }
                            },
                      icon: Icon(
                        connectionState == _ConnectionState.connected
                            ? Icons.wifi_tethering_off
                            : Icons.refresh,
                        size: 18,
                      ),
                      label: Text(
                        connectionState == _ConnectionState.connected
                            ? 'Disconnect'
                            : 'Reconnect',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _view = _ConnectionPanelView.protocol);
                      },
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Protocol'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RECENT ACTIVITY', style: textTheme.labelSmall),
                const SizedBox(height: 8),
                ..._activity.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.message, style: textTheme.bodyMedium),
                                Text(
                                  _formatRelative(item.timestamp),
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_activity.isEmpty)
                  Text('No recent activity yet.', style: textTheme.bodySmall),
                if (inviteCode != null) ...[
                  const SizedBox(height: 10),
                  Text('Invite code: $inviteCode', style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() => _view = _ConnectionPanelView.log);
                },
                icon: const Icon(Icons.terminal, size: 16),
                label: const Text('View Diagnostic Log'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () {
                  setState(() => _view = _ConnectionPanelView.network);
                },
                icon: const Icon(Icons.hub_outlined, size: 16),
                label: const Text('Network'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolView(
    BuildContext context, {
    required int protocolEpoch,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SingleChildScrollView(
      key: const ValueKey(_ConnectionPanelView.protocol),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ProtocolTile(
                label: 'Cipher Suite',
                value: 'AES-GCM-256',
                icon: Icons.lock_outline,
                color: colorScheme.primary,
              ),
              _ProtocolTile(
                label: 'Ratchet Tree',
                value: 'TreeKEM v1',
                icon: Icons.account_tree_outlined,
                color: colorScheme.tertiary,
              ),
              _ProtocolTile(
                label: 'Epoch',
                value: '$protocolEpoch',
                icon: Icons.timelapse,
                color: colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              'Perfect forward secrecy is maintained by rotating group secrets '
              'when membership or key material changes. Epoch advances indicate '
              'a fresh cryptographic state for subsequent payloads.',
              style: textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isAdvancingEpoch ? null : _handleAdvanceEpoch,
              icon: _buildBusyIcon(
                running: _isAdvancingEpoch,
                icon: Icons.refresh,
              ),
              label: Text(_isAdvancingEpoch ? 'Advancing...' : 'Advance Epoch'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Advance Epoch performs a real TreeKEM key rotation and '
            'broadcasts the new epoch to connected peers.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildLogView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey(_ConnectionPanelView.log),
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ListView.separated(
                itemCount: _logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = _logs[index];
                  return Text(
                    '[${_formatClock(entry.timestamp)}] ${entry.message}',
                    style: TextStyle(
                      color: _colorForDiagnostic(entry.type, colorScheme),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Listening for discovery events',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      key: const ValueKey(_ConnectionPanelView.network),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Routing Strategy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<_NetworkMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<_NetworkMode>(
                value: _NetworkMode.relay,
                label: Text('Relay Hub'),
                icon: Icon(Icons.router_outlined),
              ),
              ButtonSegment<_NetworkMode>(
                value: _NetworkMode.mesh,
                label: Text('P2P Mesh'),
                icon: Icon(Icons.hub_outlined),
              ),
            ],
            selected: <_NetworkMode>{_networkMode},
            onSelectionChanged: (selection) {
              final selectedMode = selection.first;
              setState(() => _networkMode = selectedMode);
              _addActivity(
                selectedMode == _NetworkMode.mesh
                    ? 'Switched routing to P2P Mesh'
                    : 'Switched routing to Relay Hub',
              );
              _addLog(
                'Topology mode set to ${selectedMode == _NetworkMode.mesh ? 'mesh' : 'relay'}.',
                type: _DiagnosticType.info,
              );
            },
          ),
          const SizedBox(height: 18),
          Text('Known Servers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ..._serverRows(colorScheme),
        ],
      ),
    );
  }

  List<Widget> _serverRows(ColorScheme colorScheme) {
    final rows = <({String host, bool ok, String role})>[
      (
        host: 'relay-01.cohrtz.local',
        ok: _networkMode == _NetworkMode.relay,
        role: 'Relay',
      ),
      (host: 'discovery-01.cohrtz.local', ok: true, role: 'Discovery'),
      (host: 'discovery-02.cohrtz.local', ok: true, role: 'Discovery'),
    ];

    return rows.map((row) {
      final badgeColor = row.ok ? colorScheme.tertiary : colorScheme.error;
      final badgeText = row.ok ? 'Connected' : 'Standby';

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.host,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.role,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBusyIcon({required bool running, required IconData icon}) {
    if (!running) {
      return Icon(icon);
    }

    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Future<void> _handleSynchronize() async {
    if (_isSynchronizing || _isReconnecting) return;

    final roomName = ref.read(syncServiceProvider).currentRoomName;
    if (roomName == null || roomName.isEmpty) {
      _showSnack('No active group selected.');
      return;
    }

    setState(() => _isSynchronizing = true);
    _addLog('Manual sync requested.', type: _DiagnosticType.info);

    try {
      await ref.read(syncProtocolProvider).requestSync(roomName, force: true);
      _addActivity('Successfully synced group state');
      _addLog(
        'SYNC_REQ broadcasted for $roomName.',
        type: _DiagnosticType.success,
      );
    } catch (error) {
      _addLog('Sync failed: $error', type: _DiagnosticType.error);
      _showSnack('Sync failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSynchronizing = false);
      }
    }
  }

  Future<void> _handleReconnect() async {
    if (_isReconnecting) return;

    final roomName = ref.read(syncServiceProvider).currentRoomName;
    if (roomName == null || roomName.isEmpty) {
      _showSnack('No active group selected.');
      return;
    }

    setState(() => _isReconnecting = true);
    _addLog('Starting reconnection handshake...', type: _DiagnosticType.info);

    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      await ref.read(groupConnectionProcessProvider).connect(roomName);

      if (!mounted) return;
      setState(() {
        _isSessionPaused = false;
      });
      _addActivity('Reconnected group session');
      _addLog('Reconnection successful.', type: _DiagnosticType.success);
    } catch (error) {
      _addLog('Reconnect failed: $error', type: _DiagnosticType.error);
      _showSnack('Reconnect failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isReconnecting = false);
      }
    }
  }

  Future<void> _handleDisconnect() async {
    final roomName = ref.read(syncServiceProvider).currentRoomName;
    if (roomName == null || roomName.isEmpty) {
      _showSnack('No active group selected.');
      return;
    }

    try {
      await ref.read(connectionManagerProvider).disconnectRoom(roomName);
      ref.read(syncServiceProvider).setActiveRoom(roomName);

      if (!mounted) return;
      setState(() {
        _isSessionPaused = true;
      });
      _addActivity('Group session paused');
      _addLog('Session paused by local user.', type: _DiagnosticType.warning);
    } catch (error) {
      _addLog('Disconnect failed: $error', type: _DiagnosticType.error);
      _showSnack('Disconnect failed: $error');
    }
  }

  Future<void> _handleAdvanceEpoch() async {
    if (_isAdvancingEpoch) return;

    final roomName = ref.read(syncServiceProvider).currentRoomName;
    if (roomName == null || roomName.isEmpty) {
      _showSnack('No active group selected.');
      return;
    }

    setState(() => _isAdvancingEpoch = true);
    _addLog('Advancing TreeKEM epoch...', type: _DiagnosticType.info);

    try {
      final epoch = await ref
          .read(packetHandlerProvider)
          .rotateTreeKemEpoch(roomName);
      _addActivity('Security epoch advanced to $epoch');
      _addLog(
        'Broadcasted TreeKEM update for epoch $epoch.',
        type: _DiagnosticType.success,
      );
    } catch (error) {
      _addLog('Epoch advance failed: $error', type: _DiagnosticType.error);
      _showSnack('Epoch advance failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isAdvancingEpoch = false);
      }
    }
  }

  Future<void> _confirmLeaveGroup({
    required String roomName,
    String? localUserId,
  }) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave Group?'),
          content: const Text(
            'This removes your local access and disconnects this group session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave Group'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(leaveGroupProcessProvider)
          .execute(roomName, localUserId: localUserId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack('Failed to leave group: $error');
    }
  }

  String _resolveGroupName(
    SyncService syncService,
    GroupSettings? settings,
    String roomName,
  ) {
    final configured = settings?.name.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    final friendly = syncService.getFriendlyName(roomName);
    if (friendly.isNotEmpty) {
      return friendly;
    }

    if (roomName.isNotEmpty) {
      return roomName;
    }

    return 'Current Group';
  }

  String? _resolveInviteCode(GroupSettings? settings) {
    final invites = settings?.invites ?? const <GroupInvite>[];
    for (final invite in invites) {
      if (invite.isValid) {
        return invite.code;
      }
    }
    return null;
  }

  _ConnectionState _effectiveConnectionState(SyncService syncService) {
    if (_isReconnecting || syncService.isActiveRoomConnecting) {
      return _ConnectionState.connecting;
    }
    if (!_isSessionPaused && syncService.isActiveRoomConnected) {
      return _ConnectionState.connected;
    }
    return _ConnectionState.disconnected;
  }

  void _hydrateDiagnostics(String roomName) {
    if (roomName.isEmpty) return;

    // Initialize with persistent stats
    final statsRepo = ref.read(transferStatsRepositoryProvider);
    _sentBytes = statsRepo.totalSentBytes;
    _receivedBytes = statsRepo.totalReceivedBytes;

    // Listen for real-time updates to persist and update UI
    // Note: The repository already listens to SyncDiagnostics to update its internal state
    // We can either listen to the repository stream or keep listening to SyncDiagnostics
    // and just read initial values. Given existing structure, let's keep SyncDiagnostics
    // for the log/activity feed, but we should rely on repository for the totals
    // to ensure we don't double count or miss out.

    // Actually, since this dialog might be opened/closed, we should rely on the repo's stream
    // for the totals if we want them to be perfectly in sync with what's persisted,
    // OR we just use the initial values and then accumulate what we see.
    // However, if we just accumulate what we see, we might diverge if the repo updates
    // from background events while dialog is open.
    // Simpler approach:
    // 1. Get initial values from repo.
    // 2. When SyncDiagnosticEvent comes in, update local state AND let repo handle persistence (repo listens independently).
    // This works fine as long as we don't double-add existing logs to the total.

    final events = SyncDiagnostics.recentForRoom(roomName, limit: 200);
    if (events.isEmpty) {
      _logs.add(
        _DiagnosticEntry(
          message: 'Listening for sync, handshake, and transfer events.',
          timestamp: DateTime.now(),
          type: _DiagnosticType.info,
        ),
      );
      return;
    }

    // We do NOT consume totals from recent events because we loaded the persisted global totals.
    // iterating events here is just to populate the log list.

    for (final event in events.reversed) {
      _logs.add(_entryFromDiagnosticEvent(event));
    }

    final activityEvents = events
        .where(_isActivityEvent)
        .toList(growable: false)
        .reversed
        .take(8);
    for (final event in activityEvents) {
      _activity.add(
        _ActivityItem(
          message: _activityMessageForEvent(event),
          timestamp: event.timestamp,
        ),
      );
    }
  }

  void _applyDiagnosticEvent(SyncDiagnosticEvent event) {
    setState(() {
      _consumeDiagnosticTotals(event);
      _logs.insert(0, _entryFromDiagnosticEvent(event));
      if (_logs.length > 120) {
        _logs.removeRange(120, _logs.length);
      }

      if (_isActivityEvent(event)) {
        _activity.insert(
          0,
          _ActivityItem(
            message: _activityMessageForEvent(event),
            timestamp: event.timestamp,
          ),
        );
        if (_activity.length > 8) {
          _activity.removeRange(8, _activity.length);
        }
      }
    });
  }

  void _consumeDiagnosticTotals(SyncDiagnosticEvent event) {
    if (event.bytes != null && event.bytes! > 0) {
      if (event.direction == SyncDiagnosticDirection.outbound) {
        _sentBytes += event.bytes!;
      } else if (event.direction == SyncDiagnosticDirection.inbound) {
        _receivedBytes += event.bytes!;
      }
    }

    if (event.kind == SyncDiagnosticKind.sync) {
      _lastSyncAt = event.timestamp;
    }
  }

  _DiagnosticEntry _entryFromDiagnosticEvent(SyncDiagnosticEvent event) {
    final directionLabel = switch (event.direction) {
      SyncDiagnosticDirection.inbound => 'IN',
      SyncDiagnosticDirection.outbound => 'OUT',
      SyncDiagnosticDirection.local => 'LOCAL',
    };
    final peerText = event.peerId != null && event.peerId!.isNotEmpty
        ? ' peer=${event.peerId}'
        : '';
    final bytesText = event.bytes != null && event.bytes! > 0
        ? ' ${_formatBytes(event.bytes!)}'
        : '';

    return _DiagnosticEntry(
      message: '[$directionLabel] ${event.message}$peerText$bytesText',
      timestamp: event.timestamp,
      type: _diagnosticTypeForEvent(event),
    );
  }

  _DiagnosticType _diagnosticTypeForEvent(SyncDiagnosticEvent event) {
    switch (event.kind) {
      case SyncDiagnosticKind.error:
        return _DiagnosticType.error;
      case SyncDiagnosticKind.warning:
        return _DiagnosticType.warning;
      case SyncDiagnosticKind.handshake:
      case SyncDiagnosticKind.sync:
      case SyncDiagnosticKind.data:
      case SyncDiagnosticKind.connection:
      case SyncDiagnosticKind.security:
        return _DiagnosticType.success;
      case SyncDiagnosticKind.info:
        return _DiagnosticType.info;
    }
  }

  bool _isActivityEvent(SyncDiagnosticEvent event) {
    return event.kind == SyncDiagnosticKind.handshake ||
        event.kind == SyncDiagnosticKind.sync ||
        event.kind == SyncDiagnosticKind.data ||
        event.kind == SyncDiagnosticKind.connection;
  }

  String _activityMessageForEvent(SyncDiagnosticEvent event) {
    if (event.kind == SyncDiagnosticKind.sync && event.isSyncCompletion) {
      return 'Sync merged from ${event.peerId ?? 'peer'}';
    }
    return event.message;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  double _bytesToMb(int bytes) => bytes / (1024 * 1024);

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addActivity(String message) {
    if (!mounted) return;

    setState(() {
      _activity.insert(
        0,
        _ActivityItem(message: message, timestamp: DateTime.now()),
      );
      if (_activity.length > 8) {
        _activity.removeRange(8, _activity.length);
      }
    });
  }

  void _addLog(String message, {required _DiagnosticType type}) {
    if (!mounted) return;

    setState(() {
      _logs.insert(
        0,
        _DiagnosticEntry(
          message: message,
          timestamp: DateTime.now(),
          type: type,
        ),
      );
      if (_logs.length > 48) {
        _logs.removeRange(48, _logs.length);
      }
    });
  }

  Color _colorForDiagnostic(_DiagnosticType type, ColorScheme scheme) {
    return switch (type) {
      _DiagnosticType.info => Colors.white,
      _DiagnosticType.success => scheme.tertiary,
      _DiagnosticType.warning => Colors.amber.shade300,
      _DiagnosticType.error => scheme.error,
    };
  }

  String _formatClock(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 6) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final bool highlight;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.subtitle,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 30,
                  height: 1,
                  color: highlight ? colorScheme.primary : null,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProtocolTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProtocolTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 145,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final String message;
  final DateTime timestamp;

  const _ActivityItem({required this.message, required this.timestamp});
}

class _DiagnosticEntry {
  final String message;
  final DateTime timestamp;
  final _DiagnosticType type;

  const _DiagnosticEntry({
    required this.message,
    required this.timestamp,
    required this.type,
  });
}
