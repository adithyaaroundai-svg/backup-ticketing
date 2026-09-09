import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/task_board_provider.dart';
import 'providers/clients_provider.dart';
import 'providers/deliverables_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/team_provider.dart';
import 'providers/activity_provider.dart';
import 'providers/billing_provider.dart';

/// Wraps the Developer CRM feature in its own isolated state management scope.
class DevCrmProviderScope extends StatefulWidget {
  final Widget child;
  final String? supportIdentifier;

  const DevCrmProviderScope({
    super.key, 
    required this.child,
    this.supportIdentifier,
  });

  @override
  State<DevCrmProviderScope> createState() => _DevCrmProviderScopeState();
}

class _DevCrmProviderScopeState extends State<DevCrmProviderScope> {
  late final AuthProvider _auth;
  late final TaskBoardProvider _taskBoard;
  late final PendingBoardProvider _pendingBoard;
  late final ClientsProvider _clients;
  late final DeliverablesProvider _deliverables;
  late final DashboardProvider _dashboard;
  late final TeamProvider _team;
  late final ActivityProvider _activity;
  late final BillingProvider _billing;
  String? _lastIdentifier;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider();
    _taskBoard = TaskBoardProvider(pendingBoard: false);
    _pendingBoard = PendingBoardProvider();
    _clients = ClientsProvider();
    _deliverables = DeliverablesProvider();
    _dashboard = DashboardProvider();
    _team = TeamProvider();
    _activity = ActivityProvider();
    _billing = BillingProvider(_auth);
    
    // Attempt auto-login if identifier is available on boot
    if (widget.supportIdentifier != null) {
      _lastIdentifier = widget.supportIdentifier;
      _auth.loginWithSupportId(widget.supportIdentifier!).then((_) {
        if (mounted && _auth.isLoggedIn) {
          // Preload primary tabs in parallel for instantaneous navigation
          _taskBoard.load(silent: true);
          _clients.load();
          _deliverables.load();
        }
      });
    }
  }

  @override
  void didUpdateWidget(DevCrmProviderScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the support user changed, auto-login as the new user
    if (widget.supportIdentifier != _lastIdentifier && widget.supportIdentifier != null) {
      _lastIdentifier = widget.supportIdentifier;
      _auth.loginWithSupportId(widget.supportIdentifier!).then((_) {
        if (mounted && _auth.isLoggedIn) {
          _taskBoard.load(silent: true);
          _clients.load();
          _deliverables.load();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<TaskBoardProvider>.value(value: _taskBoard),
        ChangeNotifierProvider<PendingBoardProvider>.value(value: _pendingBoard),
        ChangeNotifierProvider<ClientsProvider>.value(value: _clients),
        ChangeNotifierProvider<DeliverablesProvider>.value(value: _deliverables),
        ChangeNotifierProvider<DashboardProvider>.value(value: _dashboard),
        ChangeNotifierProvider<TeamProvider>.value(value: _team),
        ChangeNotifierProvider<ActivityProvider>.value(value: _activity),
        ChangeNotifierProvider<BillingProvider>.value(value: _billing),
      ],
      child: widget.child,
    );
  }
}
