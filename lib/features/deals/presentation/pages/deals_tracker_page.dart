import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../widgets/deals_table.dart';
import '../providers/deals_provider.dart';
import '../widgets/animated_create_deal_fab.dart';
import '../widgets/create_deal_dialog.dart';

class DealsTrackerPage extends ConsumerWidget {
  const DealsTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.toString();
    final gc = GlassColors.of(context, ref);

    return MainLayout(
      currentPath: currentPath,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: AnimatedCreateDealFab(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => const CreateDealDialog(),
            );
          },
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Nav / Tabs Area
            ClipRect(
              child: BackdropFilter(
                filter: gc.isGlass
                    ? ImageFilter.blur(sigmaX: 12, sigmaY: 12)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: gc.isGlass
                        ? Colors.white.withValues(alpha: 0.07)
                        : gc.surface,
                    border: Border(bottom: BorderSide(color: gc.border)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: gc.primary, width: 2),
                            ),
                          ),
                          child: Text(
                            'Deals',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: gc.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deals Tracker',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: gc.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track all your incoming deals and their current statuses.',
                      style: TextStyle(
                        fontSize: 14,
                        color: gc.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const FollowUpBanner(),
                    const DealsTable(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class FollowUpBanner extends ConsumerWidget {
  const FollowUpBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealsAsync = ref.watch(dealsProvider);
    final gc = GlassColors.of(context, ref);

    return dealsAsync.maybeWhen(
      data: (deals) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        int followUpCount = 0;
        for (var deal in deals) {
          if (deal.followUpDate != null && deal.followUpDate!.isNotEmpty) {
            final dt = DateTime.tryParse(deal.followUpDate!);
            if (dt != null) {
              final followUpDay = DateTime(dt.year, dt.month, dt.day);
              if (followUpDay.isBefore(today) || followUpDay.isAtSameMomentAs(today)) {
                followUpCount++;
              }
            }
          }
        }

        if (followUpCount == 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gc.isGlass ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.bell, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have \ deal\ that require your attention for follow-up today.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
