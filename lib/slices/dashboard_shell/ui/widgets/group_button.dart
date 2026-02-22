import 'package:flutter/material.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';
import 'group_flyout.dart';

/// A stateful widget representing a group button in the Group Selection Rail.
///
/// Features:
/// - Inactive state: 48x48 circle with surface color
/// - Active state: transforms to squircle with gradient background
/// - Left indicator pill that animates from 0 to 32px when active
/// - Hover effects and smooth 300ms transitions
/// - Discord-style flyout on hover showing group info
/// - Full ThemeData integration (no hard-coded colors)
class GroupButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isConnected;
  final int memberCount;
  final String avatarBase64;
  final String groupDescription;
  final VoidCallback? onTap;

  const GroupButton({
    super.key,
    required this.label,
    required this.icon,
    this.isActive = false,
    this.isConnected = false,
    this.memberCount = 0,
    this.avatarBase64 = '',
    this.groupDescription = '',
    this.onTap,
  });

  @override
  State<GroupButton> createState() => _GroupButtonState();
}

class _GroupButtonState extends State<GroupButton> {
  bool _isHovering = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.centerRight,
          followerAnchor: Alignment.centerLeft,
          offset: const Offset(16, 0), // 16px gap from button
          child: GroupFlyout(
            groupName: widget.label,
            isConnected: widget.isConnected,
            memberCount: widget.memberCount,
            groupAvatarBase64: widget.avatarBase64,
            groupDescription: widget.groupDescription,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleHoverEnter(PointerEvent details) {
    setState(() => _isHovering = true);
    _showOverlay();
  }

  void _handleHoverExit(PointerEvent details) {
    setState(() => _isHovering = false);
    _removeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAvatar = widget.avatarBase64.trim().isNotEmpty;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: _handleHoverEnter,
        onExit: _handleHoverExit,
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Active/Hover Indicator (Left Pill)
                Positioned(
                  left: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn,
                    width: 4,
                    height: widget.isActive ? 32 : (_isHovering ? 12 : 0),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),

                // The Group Icon Button - Layered for smooth gradient transition
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    children: [
                      // Base layer: solid color background
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.isActive || _isHovering ? 12 : 32,
                          ),
                          color: colorScheme.surfaceContainerHigh,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: widget.isActive ? 0.3 : 0.0,
                              ),
                              blurRadius: widget.isActive ? 12 : 0,
                              spreadRadius: 0,
                              offset: widget.isActive
                                  ? const Offset(0, 4)
                                  : const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),

                      // Top layer: gradient that fades in when active
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        opacity: widget.isActive ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              widget.isActive || _isHovering ? 12 : 32,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.tertiary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),

                      // Icon on top
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          child: hasAvatar
                              ? ProfileAvatar(
                                  key: ValueKey(
                                    '${widget.avatarBase64}-${widget.isActive}',
                                  ),
                                  displayName: widget.label,
                                  avatarBase64: widget.avatarBase64,
                                  size: 30,
                                  borderWidth: 2,
                                  borderColor: widget.isActive
                                      ? colorScheme.onPrimary.withValues(
                                          alpha: 0.75,
                                        )
                                      : colorScheme.surface,
                                )
                              : Icon(
                                  widget.icon,
                                  key: ValueKey(
                                    '${widget.icon}-${widget.isActive}',
                                  ),
                                  size: 20,
                                  color: widget.isActive
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
