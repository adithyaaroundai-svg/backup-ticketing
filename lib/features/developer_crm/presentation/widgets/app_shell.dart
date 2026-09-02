import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/roles.dart';
import '../../core/time_utils.dart';
import '../../domain/entities/task.dart';
import '../providers/auth_provider.dart';

class NavItem {
  final String label;
  final String path;
  final IconData icon;
  NavItem(this.label, this.path, this.icon);
}

/// Nav shell mirroring `views/partials/header.ejs`: a top bar with
/// role-filtered nav links + user menu, and a "My Tasks" sidebar sourced
/// from `GET /api/me`'s `sidebarTasks`.
class AppShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onExit;
  const AppShell({super.key, required this.onExit, required this.child});

  List<NavItem> _navItemsFor(String role) {
    final items = <NavItem>[];
    if (roleIsAccountant(role)) {
      items.add(NavItem('Billing', '/billing', Icons.receipt_long));
      return items;
    }
    if (roleCanSeeDashboard(role)) {
      items.add(NavItem('Dashboard', '/dashboard', Icons.dashboard));
    }
    items.add(NavItem('Deliverables', '/deliverables', Icons.local_shipping));
    items.add(NavItem("Today's Tasks", '/tasks', Icons.checklist));
    items.add(NavItem('Pending', '/pending', Icons.pending_actions));
    if (roleCanSeeTeam(role)) {
      items.add(NavItem('Team', '/team', Icons.groups));
    }
    if (roleCanSeeBilling(role) && role == 'manager') {
      items.add(NavItem('Billing', '/billing', Icons.receipt_long));
    }
    items.add(NavItem('Clients', '/clients', Icons.business));
    items.add(NavItem('Activity', '/activity', Icons.history));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return child;
    final navItems = _navItemsFor(user.role);
    final currentPath = GoRouterState.of(context).uri.path;
    final wide = MediaQuery.of(context).size.width >= 900;

    final sidebar = _Sidebar(navItems: navItems, currentPath: currentPath);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Support CRM',
          onPressed: onExit,
        ),
        title: const Text('Aroundai Tracker'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text('${user.name} (${userRoleLabelShort(user.role)})')),
          ),
          if (roleCanSeeSettings(user.role))
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
            ),
          IconButton(
            tooltip: 'Change password',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => context.push('/change-password'),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (wide) SizedBox(width: 260, child: sidebar),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

String userRoleLabelShort(String role) => role.replaceAll('_', ' ');

class _Sidebar extends StatelessWidget {
  final List<NavItem> navItems;
  final String currentPath;
  const _Sidebar({required this.navItems, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tasks = auth.sidebarTasks;
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final item in navItems)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: currentPath == item.path || currentPath.startsWith('${item.path}/'),
              onTap: () {
                context.go(item.path);
                if (Scaffold.of(context).hasDrawer) {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('MY TASKS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Nothing assigned to you right now.', style: TextStyle(fontSize: 12)),
            )
          else
            for (final t in tasks)
              _SidebarTaskTile(task: t, todayStr: todayStr),
        ],
      ),
    );
  }
}

class _SidebarTaskTile extends StatelessWidget {
  final Task task;
  final String todayStr;
  const _SidebarTaskTile({required this.task, required this.todayStr});

  @override
  Widget build(BuildContext context) {
    final due = task.expectedFinish;
    final overdue = due != null && due.compareTo(todayStr) < 0;
    final dueToday = due != null && due == todayStr;
    String label = task.description;
    if (label.length > 60) label = '${label.substring(0, 60)}\u2026';
    Color? color;
    if (overdue) color = Colors.red;
    if (dueToday) color = Colors.orange;
    return ListTile(
      dense: true,
      title: Text(label, style: TextStyle(fontSize: 13, color: color)),
      subtitle: Text(
        [
          if (task.client != null) task.client!,
          overdue
              ? 'Overdue \u00b7 ${fmtDate(due)}'
              : dueToday
                  ? 'Due today'
                  : due != null
                      ? 'Due ${fmtDate(due)}'
                      : 'No due date',
        ].join(' \u2022 '),
        style: const TextStyle(fontSize: 11),
      ),
      onTap: () => context.push('/tasks/${task.id}'),
    );
  }
}
