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
  if (path.startsWith('/dashboard')) return roleCanSeeDashboard(role);
  if (path.startsWith('/settings')) return roleCanSeeSettings(role);
  if (path.startsWith('/billing')) return roleCanSeeBilling(role);
  if (path.startsWith('/team')) return roleCanSeeTeam(role);
  if (roleIsAccountant(role)) {
    const accountantAllowed = ['/billing', '/change-password', '/activity'];
    return accountantAllowed.any((p) => path == p || path.startsWith('$p/'));
  }
  return true;
}

GoRouter buildDevCrmRouter(AuthProvider auth, VoidCallback onExit) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!auth.initialized) {
        return loc == '/' ? null : null;
      }
      final loggedIn = auth.isLoggedIn;
      final atChangePassword = loc == '/change-password';

      if (!loggedIn) {
        return '/unauthorized';
      }
      if (auth.mustChangePassword) {
        return atChangePassword ? null : '/change-password';
      }
      if (loc == '/' || loc == '/unauthorized') {
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
        path: '/unauthorized', 
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
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) =>
            ClientDetailScreen(clientId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/work-items/:id/edit',
        builder: (context, state) =>
            WorkItemEditScreen(workItemId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (context, state) => TaskEditScreen(taskId: int.parse(state.pathParameters['id']!)),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(onExit: onExit, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/clients', builder: (context, state) => const ClientsScreen()),
          GoRoute(path: '/deliverables', builder: (context, state) => const DeliverablesScreen()),
          GoRoute(path: '/tasks', builder: (context, state) => const TaskBoardScreen()),
          GoRoute(path: '/pending', builder: (context, state) => const PendingBoardScreen()),
          GoRoute(path: '/billing', builder: (context, state) => const BillingScreen()),
          GoRoute(path: '/team', builder: (context, state) => const TeamScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
        ],
      ),
    ],
  );
}
