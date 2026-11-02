import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/app_update_service.dart';
import 'force_update_view.dart';

/// AppUpdateGate wraps the entire application. It monitors the app lifecycle
/// and remote version control settings. When a mandatory update is detected,
/// it securely replaces the app interface with [ForceUpdateView].
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateGate({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns to the app from Google Play or background, re-check version
    if (state == AppLifecycleState.resumed) {
      ref.read(appUpdateProvider.notifier).check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(appUpdateProvider);

    return updateState.maybeWhen(
      data: (result) {
        if (result == null) return widget.child;

        // Mandatory Force Update: Lock the screen
        if (result.isForceUpdate) {
          return ForceUpdateView(result: result);
        }

        // Flexible Update: Display a polite banner at the top, without blocking
        if (result.isFlexibleUpdate) {
          return Stack(
            children: [
              widget.child,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF1E40AF),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.sparkles,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'A new update (v${result.config.latestVersionName}) is available!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(appUpdateServiceProvider)
                                    .openPlayStore(
                                      customUrl: result.config.playStoreUrl,
                                    );
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1E40AF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Update',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.x,
                                color: Colors.white70,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ref
                                    .read(appUpdateProvider.notifier)
                                    .dismissFlexible();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return widget.child;
      },
      orElse: () => widget.child,
    );
  }
}
