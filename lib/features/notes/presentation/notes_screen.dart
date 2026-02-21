import 'package:flutter/material.dart';
import 'widgets/notes_widget.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(padding: EdgeInsets.all(24), child: NotesWidget()),
    );
  }
}
