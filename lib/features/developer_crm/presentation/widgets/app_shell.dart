import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider;

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/theme/theme_provider.dart';
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
      items.add(NavItem('Billing', '/dev-crm/billing', Icons.receipt_long));
      return items;
    }
    if (roleCanSeeDashboard(role)) {
      items.add(NavItem('Dashboard', '/dev-crm/dashboard', Icons.dashboard));
    }
    items.add(NavItem('Deliverables', '/dev-crm/deliverables', Icons.local_shipping));
    items.add(NavItem("Today's Tasks", '/dev-crm/tasks', Icons.checklist));
    items.add(NavItem('Pending', '/dev-crm/pending', Icons.pending_actions));
    if (roleCanSeeTeam(role)) {
      items.add(NavItem('Team', '/dev-crm/team', Icons.groups));
    }
    if (roleCanSeeBilling(role) && role == 'manager') {
      items.add(NavItem('Billing', '/dev-crm/billing', Icons.receipt_long));
    }
    items.add(NavItem('Clients', '/dev-crm/clients', Icons.business));
    items.add(NavItem('Activity', '/dev-crm/activity', Icons.history));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final auth = provider.Provider.of<AuthProvider>(context);
        final user = auth.user;
        if (user == null) return child;
        final themeType = ref.watch(themeProvider);
        final isPink = themeType == AppThemeType.pink;
        final isDark = themeType != AppThemeType.white;
        final navItems = _navItemsFor(user.role);
        final currentPath = GoRouterState.of(context).uri.path;
        final wide = MediaQuery.of(context).size.width >= 900;

        final sidebar = _Sidebar(
          navItems: navItems,
          currentPath: currentPath,
          isPink: isPink,
        );

        final barColor = isPink
            ? AppColors.pinkThemeNav
            : isDark
                ? AppColors.slate900
                : Colors.white;
        final barForeground = isDark || isPink ? Colors.white : AppColors.slate900;

        return Scaffold(
          backgroundColor: isDark ? AppColors.slate950 : AppColors.background,
          appBar: AppBar(
            backgroundColor: barColor,
            foregroundColor: barForeground,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: Border(
              bottom: BorderSide(color: isDark || isPink ? Colors.white12 : AppColors.border),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Support CRM',
              onPressed: onExit,
            ),
            title: Text(
              'Aroundai Tracker',
              style: TextStyle(color: barForeground, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                    decoration: BoxDecoration(
                      color: isDark || isPink ? Colors.white.withValues(alpha: 0.08) : AppColors.slate100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            user.name.isEmpty ? '?' : user.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            '${user.name} · ${userRoleLabelShort(user.role)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: barForeground, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (roleCanSeeSettings(user.role))
                IconButton(
                  tooltip: 'Settings',
                  icon: Icon(Icons.settings, color: barForeground),
                  onPressed: () => context.push('/dev-crm/settings'),
                ),
              IconButton(
                tooltip: 'Change password',
                icon: Icon(Icons.lock_outline, color: barForeground),
                onPressed: () => context.push('/dev-crm/change-password'),
              ),
            ],
          ),
          drawer: wide ? null : Drawer(backgroundColor: Colors.transparent, child: sidebar),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) SizedBox(width: 260, child: sidebar),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

String userRoleLabelShort(String role) => role.replaceAll('_', ' ');

class _Sidebar extends StatelessWidget {
  final List<NavItem> navItems;
  final String currentPath;
  final bool isPink;
  const _Sidebar({
    required this.navItems,
    required this.currentPath,
    required this.isPink,
  });

  @override
  Widget build(BuildContext context) {
    final auth = provider.Provider.of<AuthProvider>(context);
    final tasks = auth.sidebarTasks;
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: isPink ? AppColors.pinkThemeSidebar : null,
        gradient: isPink
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryDark, AppColors.slate900],
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        children: [
          for (final item in navItems)
            _NavTile(item: item, currentPath: currentPath),
          const Divider(color: Colors.white24, height: 24),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(
              'MY TASKS',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Nothing assigned to you right now.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            )
          else
            for (final t in tasks)
              _SidebarTaskTile(task: t, todayStr: todayStr),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final String currentPath;
  const _NavTile({required this.item, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final selected = currentPath == item.path || currentPath.startsWith('${item.path}/');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.go(item.path);
            if (Scaffold.of(context).hasDrawer) {
              Navigator.of(context).maybePop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(item.icon, size: 18, color: selected ? Colors.white : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    Color color = Colors.white70;
    if (overdue) color = const Color(0xFFFCA5A5);
    if (dueToday) color = const Color(0xFFFDBA74);
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
        style: const TextStyle(fontSize: 11, color: Colors.white54),
      ),
      onTap: () => context.push('/tasks/${task.id}'),
    );
  }
}
