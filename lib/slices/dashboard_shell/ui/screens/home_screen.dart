import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/sync/ui/widgets/connection_status_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard_layout.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isAutoJoining = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoJoin();
    });
  }

  Future<void> _checkAutoJoin() async {
    if (mounted) setState(() => _isAutoJoining = true);
    try {
      final connectionProcess = ref.read(groupConnectionProcessProvider);
      await connectionProcess.autoJoinSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Auto-join failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAutoJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If auto-joining, show splash/loader
    return Stack(
      children: [
        // The main dashboard content (Menu, Groups, etc.)
        const DashboardLayout(),

        // If auto-joining, show splash/loader OVER everything not covered by modal?
        // Actually, if auto-joining, we might want to cover everything.
        if (_isAutoJoining)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(child: CircularProgressIndicator()),
          ),

        // The Status Modal (stepper)
        const ConnectionStatusModal(),
      ],
    );
  }
}
