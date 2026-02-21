import 'package:flutter/material.dart';

class GroupDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;
  final int? badgeCount;

  const GroupDrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.textColor,
    this.iconColor,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? Theme.of(context).colorScheme.secondaryContainer
        : Colors.transparent;

    final fgColor = isSelected
        ? Theme.of(context).colorScheme.onSecondaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final finalTextColor = textColor ?? fgColor;
    final finalIconColor = iconColor ?? fgColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: finalIconColor, size: 18),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: finalTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount! > 99 ? '99+' : badgeCount.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: onTap,
        dense: true,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        minLeadingWidth: 18,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
