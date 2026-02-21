import 'package:flutter/material.dart';

import '../../../notes/ui/widgets/notes_widget.dart';

class NotesPage extends StatelessWidget {
  final String? initialDocumentId;
  final ValueChanged<String>? onDocumentChanged;

  const NotesPage({super.key, this.initialDocumentId, this.onDocumentChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: NotesWidget(
        initialDocumentId: initialDocumentId,
        onDocumentChanged: onDocumentChanged,
      ),
    );
  }
}
