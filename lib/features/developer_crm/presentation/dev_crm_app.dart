import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../../../core/design_system/theme/app_theme.dart';
import '../../../core/design_system/theme/theme_provider.dart';
import 'dev_crm_provider_scope.dart';
import 'dev_crm_router.dart';
import 'providers/auth_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart' as support_auth;

class DeveloperCrmEntryApp extends riverpod.ConsumerStatefulWidget {
  final VoidCallback onExit;
  const DeveloperCrmEntryApp({super.key, required this.onExit});

  @override
  riverpod.ConsumerState<DeveloperCrmEntryApp> createState() => _DeveloperCrmEntryAppState();
}

class _DeveloperCrmEntryAppState extends riverpod.ConsumerState<DeveloperCrmEntryApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    final supportAgent = ref.watch(support_auth.authProvider);
    final identifier = supportAgent?.id;

    return DevCrmProviderScope(
      supportIdentifier: identifier,
      child: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (_router == null) {
            _router = buildDevCrmRouter(auth, widget.onExit);
          }
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Project Tracker',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ref.watch(themeProvider) == AppThemeType.white
                ? ThemeMode.light
                : ThemeMode.dark,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
