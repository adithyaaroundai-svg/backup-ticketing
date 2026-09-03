import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  String? _lastIdentifier;

  @override
  void initState() {
    super.initState();
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
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
      ],
      child: widget.child,
    );
  }
}
