import 'package:flutter/material.dart';

import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';

String visibilitySelectionSummary({
  required List<String> selectedGroupIds,
  required List<LogicalGroup> allGroups,
}) {
  final normalized = normalizeVisibilityGroupIds(selectedGroupIds);
  if (normalized.length == 1 && normalized.first == AclGroupIds.everyone) {
    return 'Everyone';
  }

  final namesById = {for (final group in allGroups) group.id: group.name};
  final labels = normalized
      .map((id) => namesById[id] ?? id)
      .where((name) => name.isNotEmpty)
      .toList();
  if (labels.isEmpty) return 'Everyone';
  if (labels.length <= 2) return labels.join(', ');
  return '${labels.length} groups';
}

Future<List<String>?> showVisibilityGroupSelectorDialog({
  required BuildContext context,
  required List<LogicalGroup> groups,
  required List<String> initialSelection,
}) async {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _VisibilityGroupSelectorDialog(
      groups: groups,
      initialSelection: initialSelection,
    ),
  );
}

class _VisibilityGroupSelectorDialog extends StatefulWidget {
  final List<LogicalGroup> groups;
  final List<String> initialSelection;

  const _VisibilityGroupSelectorDialog({
    required this.groups,
    required this.initialSelection,
  });

  @override
  State<_VisibilityGroupSelectorDialog> createState() =>
      _VisibilityGroupSelectorDialogState();
}

class _VisibilityGroupSelectorDialogState
    extends State<_VisibilityGroupSelectorDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = normalizeVisibilityGroupIds(widget.initialSelection).toSet();
  }

  void _toggle(String id, bool enabled) {
    setState(() {
      if (id == AclGroupIds.everyone) {
        if (enabled) {
          _selected = {AclGroupIds.everyone};
          return;
        }
      } else {
        if (enabled) {
          _selected.remove(AclGroupIds.everyone);
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      }

      if (_selected.isEmpty || _selected.contains(AclGroupIds.everyone)) {
        _selected = {AclGroupIds.everyone};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Visibility Groups'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: widget.groups.map((group) {
            final selected = _selected.contains(group.id);
            final subtitle = group.id == AclGroupIds.everyone
                ? 'Visible to all group members'
                : '${group.memberIds.length} members';
            return CheckboxListTile(
              value: selected,
              onChanged: (value) => _toggle(group.id, value ?? false),
              title: Row(
                children: [
                  Expanded(child: Text(group.name)),
                  if (group.isSystem)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        'SYSTEM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(subtitle),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }).toList(),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, normalizeVisibilityGroupIds(_selected)),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
