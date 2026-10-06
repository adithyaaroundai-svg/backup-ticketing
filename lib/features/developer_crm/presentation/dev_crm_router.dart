import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/roles.dart';
import 'providers/auth_provider.dart';
import 'pages/activity_screen.dart';
import 'pages/billing_screen.dart';
import 'pages/change_password_screen.dart';
import 'pages/client_detail_screen.dart';
import 'pages/clients_screen.dart';
import 'pages/dashboard_screen.dart';
import 'pages/deliverables_screen.dart';
import 'pages/pending_board_screen.dart';
import 'pages/settings_screen.dart';
import 'pages/task_board_screen.dart';
import 'pages/task_edit_screen.dart';
import 'pages/team_screen.dart';
import 'pages/work_item_edit_screen.dart';
import 'widgets/app_shell.dart';

bool _roleAllowed(String role, String path) {
  final normalized = path.startsWith('/dev-crm') ? path : '/dev-crm$path';
  if (normalized.startsWith('/dev-crm/dashboard')) return roleCanSeeDashboard(role);
  if (normalized.startsWith('/dev-crm/settings')) return roleCanSeeSettings(role);
  if (normalized.startsWith('/dev-crm/billing')) return roleCanSeeBilling(role);
  if (normalized.startsWith('/dev-crm/team')) return roleCanSeeTeam(role);
  if (roleIsAccountant(role)) {
    const accountantAllowed = ['/dev-crm/billing', '/dev-crm/change-password', '/dev-crm/activity'];
    return accountantAllowed.any((p) => normalized == p || normalized.startsWith('$p/'));
  }
  return true;
}

GoRouter buildDevCrmRouter(AuthProvider auth, VoidCallback onExit) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.uri.path;
      if (!auth.initialized) {
        return null;
      }
      final loggedIn = auth.isLoggedIn;
      final atChangePassword = loc == '/dev-crm/change-password';

      if (!loggedIn) {
        return loc == '/dev-crm/unauthorized' ? null : '/dev-crm/unauthorized';
      }
      if (auth.mustChangePassword) {
        return atChangePassword ? null : '/dev-crm/change-password';
      }
      if (loc == '/' || loc == '/unauthorized' || loc == '/dev-crm/unauthorized' || loc == '/developer-crm') {
        return landingRouteFor(auth.user!.role);
      }
      if (!_roleAllowed(auth.user!.role, loc)) {
        return landingRouteFor(auth.user!.role);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(
        path: '/dev-crm/unauthorized', 
        builder: (context, state) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                auth.error ?? 'Not Authorized for Developer CRM. Your email must be registered in the Developer CRM users table.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        )
      ),
      GoRoute(path: '/dev-crm/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
        path: '/dev-crm/clients/:id',
        builder: (context, state) =>
            ClientDetailScreen(clientId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) =>
            ClientDetailScreen(clientId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/dev-crm/work-items/:id/edit',
        builder: (context, state) =>
            WorkItemEditScreen(workItemId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/work-items/:id/edit',
        builder: (context, state) =>
            WorkItemEditScreen(workItemId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/dev-crm/tasks/:id',
        builder: (context, state) => TaskEditScreen(taskId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (context, state) => TaskEditScreen(taskId: int.parse(state.pathParameters['id']!)),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(onExit: onExit, child: child),
        routes: [
          GoRoute(path: '/dev-crm/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/dashboard', redirect: (context, state) => '/dev-crm/dashboard'),
          GoRoute(path: '/dev-crm/clients', builder: (context, state) => const ClientsScreen()),
          GoRoute(path: '/clients', redirect: (context, state) => '/dev-crm/clients'),
          GoRoute(path: '/dev-crm/deliverables', builder: (context, state) => const DeliverablesScreen()),
          GoRoute(path: '/deliverables', redirect: (context, state) => '/dev-crm/deliverables'),
          GoRoute(path: '/dev-crm/tasks', builder: (context, state) => const TaskBoardScreen()),
          GoRoute(path: '/tasks', redirect: (context, state) => '/dev-crm/tasks'),
          GoRoute(path: '/dev-crm/pending', builder: (context, state) => const PendingBoardScreen()),
          GoRoute(path: '/pending', redirect: (context, state) => '/dev-crm/pending'),
          GoRoute(path: '/dev-crm/billing', builder: (context, state) => const BillingScreen()),
          GoRoute(path: '/billing', redirect: (context, state) => '/dev-crm/billing'),
          GoRoute(path: '/dev-crm/team', builder: (context, state) => const TeamScreen()),
          GoRoute(path: '/team', redirect: (context, state) => '/dev-crm/team'),
          GoRoute(path: '/dev-crm/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/settings', redirect: (context, state) => '/dev-crm/settings'),
          GoRoute(path: '/dev-crm/activity', builder: (context, state) => const ActivityScreen()),
          GoRoute(path: '/activity', redirect: (context, state) => '/dev-crm/activity'),
        ],
      ),
    ],
  );
}
