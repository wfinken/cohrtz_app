import 'package:flutter/material.dart';
import '../../ui/widgets/user_list_widget.dart';
import '../widgets/logical_groups_widget.dart';

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: UserListWidget(isFullPage: true),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(flex: 2, child: LogicalGroupsWidget()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
