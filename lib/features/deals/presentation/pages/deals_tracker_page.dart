import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/deals_table.dart';
import '../providers/deals_provider.dart';
import '../widgets/animated_create_deal_fab.dart';
import '../widgets/create_deal_dialog.dart';
import '../widgets/deal_register_recipients_tab.dart';
import '../../services/deal_summary_service.dart';
import '../../services/deal_follow_up_service.dart';
import '../widgets/deal_follow_up_dialog.dart';

class DealsTrackerPage extends ConsumerStatefulWidget {
  const DealsTrackerPage({super.key});

  @override
  ConsumerState<DealsTrackerPage> createState() => _DealsTrackerPageState();
}

class _DealsTrackerPageState extends ConsumerState<DealsTrackerPage> {
  int _selectedTabIndex = 0; // 0 = Deals Table, 1 = Deal Register Recipients

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DealSummaryService.startScheduler(ref);
    });
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      final agent = ref.read(authProvider);
      if (agent?.isSales == true) {
        context.go('/sales');
      } else if (agent?.isSupport == true || agent?.isHR == true || agent?.isProjectCoordinator == true) {
        context.go('/support');
      } else if (agent?.isSoftwareDeveloper == true) {
        context.go('/dev-crm/dashboard');
      } else {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = GlassColors.of(context, ref);

    return Scaffold(
      backgroundColor: gc.isGlass ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _selectedTabIndex == 0
          ? AnimatedCreateDealFab(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const CreateDealDialog(),
                );
              },
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Nav / Header Area with Back Button & Tab Switcher
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _handleBack(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: gc.isGlass
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : gc.surfaceHeader,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: gc.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.arrowLeft, size: 16, color: gc.onSurface),
                                const SizedBox(width: 8),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: gc.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        height: 24,
                        width: 1,
                        color: gc.border,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(LucideIcons.briefcase, size: 18, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Deals Tracker',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: gc.onSurface,
                        ),
                      ),
                      const Spacer(),

                      // Segmented Tabs Control
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: gc.isGlass
                              ? Colors.white.withValues(alpha: 0.08)
                              : gc.surfaceHeader,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gc.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _tabItem(
                              index: 0,
                              label: 'Deals Tracker',
                              icon: LucideIcons.tableProperties,
                              gc: gc,
                            ),
                            _tabItem(
                              index: 1,
                              label: 'Deal Register & Summary',
                              icon: LucideIcons.send,
                              gc: gc,
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    if (_selectedTabIndex == 0) ...[
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
                    ] else ...[
                      const DealRegisterRecipientsTab(),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem({
    required int index,
    required String label,
    required IconData icon,
    required GlassColors gc,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (gc.isGlass ? Colors.white.withValues(alpha: 0.15) : gc.surface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF10B981) : gc.onSurfaceMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? gc.onSurface : gc.onSurfaceMuted,
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
    final currentAgent = ref.watch(authProvider);
    if (currentAgent == null) return const SizedBox.shrink();

    // Invalidate/re-fetch when dealsProvider updates
    ref.watch(dealsProvider);

    return FutureBuilder<List<Deal>>(
      future: DealFollowUpService.getDueFollowUpDeals(currentAgent.id),
      builder: (context, snapshot) {
        final dueDeals = snapshot.data ?? [];
        if (dueDeals.isEmpty) return const SizedBox.shrink();

        final followUpCount = dueDeals.length;
        final gc = GlassColors.of(context, ref);

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: gc.isGlass ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFFFFFBEB),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.bellRing, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have $followUpCount deal${followUpCount == 1 ? '' : 's'} that require your attention for follow-up today.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => DealFollowUpDialog(
                      initialDeals: dueDeals,
                    ),
                  );
                },
                icon: const Icon(LucideIcons.listTodo, size: 15),
                label: const Text('View Follow-Ups'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
