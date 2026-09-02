import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import 'providers/auth_provider.dart';

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
  late final ApiClient _api;
  String? _lastIdentifier;

  @override
  void initState() {
    super.initState();
    // ApiClient is a dummy stub now; will be completely removed in Phase 3
    _api = ApiClient(tokenGetter: () => _auth.token);
    _auth = AuthProvider();
    
    // Attempt auto-login if identifier is available on boot
    if (widget.supportIdentifier != null) {
      _lastIdentifier = widget.supportIdentifier;
      _auth.loginWithSupportId(widget.supportIdentifier!);
    }
  }

  @override
  void didUpdateWidget(DevCrmProviderScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the support user changed, auto-login as the new user
    if (widget.supportIdentifier != _lastIdentifier && widget.supportIdentifier != null) {
      _lastIdentifier = widget.supportIdentifier;
      _auth.loginWithSupportId(widget.supportIdentifier!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
      ],
      child: widget.child,
    );
  }
}
