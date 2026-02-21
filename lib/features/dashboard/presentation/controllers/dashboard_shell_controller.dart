import '../../domain/dashboard_models.dart';

class DashboardShellController {
  DashboardView coerceViewByPermissions(
    DashboardView currentView, {
    required bool canViewVault,
    required bool canViewCalendar,
    required bool canViewTasks,
    required bool canViewNotes,
    required bool canViewMembers,
    required bool canViewChat,
    required bool canViewPolls,
  }) {
    if (currentView == DashboardView.vault && !canViewVault) {
      return DashboardView.dashboard;
    }
    if (currentView == DashboardView.calendar && !canViewCalendar) {
      return DashboardView.dashboard;
    }
    if (currentView == DashboardView.tasks && !canViewTasks) {
      return DashboardView.dashboard;
    }
    if (currentView == DashboardView.notes && !canViewNotes) {
      return DashboardView.dashboard;
    }
    if (currentView == DashboardView.members && !canViewMembers) {
      return DashboardView.dashboard;
    }
    if (currentView == DashboardView.channels && !canViewChat) {
      return DashboardView.dashboard;
    }
    if (currentView == DashboardView.polls && !canViewPolls) {
      return DashboardView.dashboard;
    }
    return currentView;
  }
}
