import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

import '../../../features/tickets/presentation/providers/ticket_provider.dart';
import '../../../features/customers/presentation/providers/customer_provider.dart';
import '../../../features/dashboard/presentation/providers/app_settings_provider.dart';
import '../../network/connectivity_provider.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../../../features/chat/presentation/providers/custom_channel_provider.dart';
import '../../../features/chat/presentation/widgets/create_channel_dialog.dart';
import '../../../features/chat/presentation/widgets/new_dm_dialog.dart';
import '../../../features/tickets/domain/entities/ticket.dart';
import '../../../features/chat/presentation/widgets/chat_toast_overlay.dart';
import '../../../features/productivity/presentation/widgets/add_reminder_dialog.dart';
import '../../../features/productivity/presentation/widgets/reminder_toast_overlay.dart';
import '../../../features/productivity/presentation/providers/reminder_provider.dart';
import '../../../features/deals/presentation/providers/deals_provider.dart';
import '../../../features/sales/presentation/providers/lead_provider.dart';
import '../../services/reminder_sound_service.dart';
import '../../services/chat_sound_service.dart';
// -- Layout State Providers ---------------------------------------------------
class TicketPaneOpenNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final ticketPaneOpenProvider = NotifierProvider<TicketPaneOpenNotifier, bool>(
  TicketPaneOpenNotifier.new,
);

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String currentPath;

  const MainLayout({super.key, required this.child, required this.currentPath});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  double _firstPaneWidth = 240;
  final double _minPaneWidth = 180;
  final double _maxPaneWidth = 400;
  bool _isMobileSidebarOpen = false;
  Timer? _lastSeenUpdateTimer;
  bool _isDisposed = false;
  bool _hasInitialized = false;
  ProviderSubscription? _chatListenerSubscription;
  ProviderSubscription? _aroundTallyListenerSubscription;
  ProviderContainer? _container;

  // Restricted agents check
  static const _allowedAroundTallyChannelIds = {
    'd7a9e726-9520-4cc8-95a6-b38a4afd1d7b',
    'dedce60a-56bd-49fd-bbe2-f88534b8e36f',
  };
  bool get _isRestrictedAgent {
    final currentUser = ref.read(authProvider);
    return _allowedAroundTallyChannelIds.contains(currentUser?.id ?? '');
  }

  @override
  void initState() {
    super.initState();
    // Listen once for the lifetime of the layout widget — never re-registers
    // on navigation rebuilds, so old messages never re-fire.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed && !_hasInitialized) {
        _hasInitialized = true;
        _setupChatListener();
        _startLastSeenUpdates();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the container so async callbacks never look up an ancestor after deactivation
    _container = ProviderScope.containerOf(context);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hasInitialized = false;
    _chatListenerSubscription?.close();
    _chatListenerSubscription = null;
    _aroundTallyListenerSubscription?.close();
    _aroundTallyListenerSubscription = null;
    _lastSeenUpdateTimer?.cancel();
    _lastSeenUpdateTimer = null;
    _container = null;
    super.dispose();
  }

  void _startLastSeenUpdates() {
    // Update last_seen immediately on start
    final container = _container;
    if (container != null && !_isDisposed) {
      final currentUser = container.read(authProvider);
      if (currentUser != null) {
        _updateLastSeen(currentUser.id);
      }
    }
    // Then update every 2 minutes while user is active
    _lastSeenUpdateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      final c = _container;
      if (_isDisposed || c == null || _lastSeenUpdateTimer == null) {
        timer.cancel();
        return;
      }
      final currentUser = c.read(authProvider);
      if (currentUser != null) {
        _updateLastSeen(currentUser.id);
      }
      // Also refresh agents list to get updated last_seen from other users
      if (!_isDisposed && _container != null) {
        c.invalidate(agentsListProvider);
      }
    });
  }

  Future<void> _updateLastSeen(String agentId) async {
    if (_isDisposed || _container == null) return;
    try {
      final client = Supabase.instance.client;
      await client
          .from('agents')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('id', agentId);
    } catch (e) {
      // Silently fail - this is non-critical
    }
  }

  void _setupChatListener() {
    final c = _container;
    if (c == null) return;
    // Use ProviderContainer.listen() directly — never touches the widget tree
    _chatListenerSubscription = c.listen(chatStreamProvider('support-chat'), (
      previous,
      next,
    ) {
      if (_isDisposed || _container == null) return;
      final myId = c.read(authProvider)?.id;
      if (myId == null) return;
      if (widget.currentPath.startsWith('/chat')) return;

      // Skip the very first emission (historical data load)
      if (previous == null) return;

      final prevMessages = previous.value ?? [];
      final nextMessages = next.value ?? [];
      if (nextMessages.length <= prevMessages.length) return;

      final prevIds = prevMessages.map((m) => m.id).toSet();

      // Only consider messages that are:
      //  1. Not in the previous snapshot (truly new this emission)
      //  2. Not sent by the current user
      //  3. Newer than the user's last-seen timestamp (not already read)
      final lastSeen = c.read(chatLastSeenProvider).value;
      final newMessages = nextMessages
          .where(
            (m) =>
                !prevIds.contains(m.id) &&
                m.senderId.trim().toLowerCase() != myId.trim().toLowerCase() &&
                (lastSeen == null || m.createdAt.toUtc().isAfter(lastSeen)),
          )
          .toList();

      if (newMessages.isNotEmpty) {
        final myFullName = c.read(authProvider)?.fullName ?? '';
        final hasMention = myFullName.isNotEmpty && 
            newMessages.any((m) => m.content.contains('@$myFullName') == true);
            
        if (hasMention) {
          ChatSoundService.playMentionPing();
        } else {
          ChatSoundService.playPing();
        }
        
        if (!_isDisposed && _container != null) {
          c.read(chatNewMessageEventProvider.notifier).notify(newMessages.last);
        }
      }
    });

    // All-AroundTally channel listener
    _aroundTallyListenerSubscription = c.listen(
      chatStreamProvider('all-aroundtally'),
      (previous, next) {
        if (_isDisposed || _container == null) return;
        final myId = c.read(authProvider)?.id;
        if (myId == null) return;
        if (widget.currentPath.startsWith('/channel/all-aroundtally')) return;

        // Skip the very first emission (historical data load)
        if (previous == null) return;

        final prevMessages = previous.value ?? [];
        final nextMessages = next.value ?? [];
        if (nextMessages.length <= prevMessages.length) return;

        final prevIds = prevMessages.map((m) => m.id).toSet();

        // Only consider messages that are:
        //  1. Not in the previous snapshot (truly new this emission)
        //  2. Not sent by the current user
        //  3. Newer than the user's last-seen timestamp (not already read)
        final lastSeen = c.read(allAroundTallyLastSeenProvider).value;
        final newMessages = nextMessages
            .where(
              (m) =>
                  !prevIds.contains(m.id) &&
                  m.senderId.trim().toLowerCase() !=
                      myId.trim().toLowerCase() &&
                  (lastSeen == null || m.createdAt.toUtc().isAfter(lastSeen)),
            )
            .toList();

        if (newMessages.isNotEmpty) {
          final myFullName = c.read(authProvider)?.fullName ?? '';
          final hasMention = myFullName.isNotEmpty && 
              newMessages.any((m) => m.content.contains('@$myFullName') == true);
              
          if (hasMention) {
            ChatSoundService.playMentionPing();
          } else {
            ChatSoundService.playPing();
          }
          
          if (!_isDisposed && _container != null) {
            c
                .read(allAroundTallyNewMessageEventProvider.notifier)
                .notify(newMessages.last);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep reminders provider alive for sound notifications
    ref.watch(remindersProvider);
    // Note: chatStreamProvider is already listened to in _setupChatListener,
    // no need to watch it here to avoid unnecessary rebuilds

    // Reminder sound
    ref.listen(lastTriggeredReminderProvider, (previous, next) {
      if (!mounted || _isDisposed) return;
      final prevIds = previous?.map((r) => r.id).toSet() ?? {};
      final nextIds = next.map((r) => r.id).toSet();
      if (nextIds.difference(prevIds).isNotEmpty) {
        ReminderSoundService.playBeep();
      }
    });

    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return ChatToastOverlay(
        currentPath: widget.currentPath,
        child: ReminderToastOverlay(
          child: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: _firstPaneWidth,
                  child: _LeftNav(currentPath: widget.currentPath),
                ),
                _ResizeHandle(
                  onDrag: (delta) {
                    setState(() {
                      _firstPaneWidth = (_firstPaneWidth + delta).clamp(
                        _minPaneWidth,
                        _maxPaneWidth,
                      );
                    });
                  },
                ),
                if (!_isRestrictedAgent && !widget.currentPath.startsWith('/sales-channel'))
                  _CollapsibleTicketPane(
                    currentPath: widget.currentPath,
                    isOpen: ref.watch(ticketPaneOpenProvider),
                    onToggle: () => ref.read(ticketPaneOpenProvider.notifier).toggle(),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      const _OfflineBanner(),
                      _TopNav(currentPath: widget.currentPath),
                      const Divider(height: 1, color: AppColors.border),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isChatRoute =
        widget.currentPath.startsWith('/chat') ||
        widget.currentPath.startsWith('/calls') ||
        widget.currentPath.startsWith('/channel') ||
        (widget.currentPath.startsWith('/sales-channel') && 
          (GoRouterState.of(context).uri.queryParameters['tab'] ?? '0') == '0');
    final double sidebarWidth = 250.0;

    return ChatToastOverlay(
      currentPath: widget.currentPath,
      child: ReminderToastOverlay(
        child: Scaffold(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _OfflineBanner(),
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(currentPath: widget.currentPath),
        ),
      ),
    );
  }
}

class _TopNav extends ConsumerWidget {
  final String currentPath;

  const _TopNav({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);

    final appSettings = ref
        .watch(appSettingsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final advSettings = ref
        .watch(advancedSettingsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    // Alert counts not shown in nav anymore.

    final role = currentUser?.role ?? 'Support';
    final isSales = currentUser?.isSales == true;
    final isTeleCaller = currentUser?.isTeleCaller == true;
    final simplifyNav =
        currentUser?.isSupport == true ||
        currentUser?.isHR == true ||
        currentUser?.isProjectCoordinator == true ||
        currentUser?.isSupportHead == true ||
        isTeleCaller;

    // Restricted agents check
    const allowedAroundTallyChannelIds = {
      'd7a9e726-9520-4cc8-95a6-b38a4afd1d7b',
      'dedce60a-56bd-49fd-bbe2-f88534b8e36f',
    };
    final isRestrictedAgent = allowedAroundTallyChannelIds.contains(
      currentUser?.id ?? '',
    );

    // Feature flags (global enable/disable)
    final enableNotifications = appSettings == null
        ? true
        : (appSettings['enable_notifications'] ?? true);
    final enableGlobalSearch = appSettings == null
        ? true
        : (appSettings['enable_global_search'] ?? true);
    final enableReports = appSettings == null
        ? true
        : (appSettings['enable_reports'] ?? true);
    final enableDeals = appSettings == null
        ? true
        : (appSettings['enable_deals'] ?? true);

    // Per-role screen visibility (uses advanced settings if available)
    bool canSeeScreen(String screenId) {
      if (advSettings == null) return true;
      return advSettings.canRoleSeeScreen(role, screenId);
    }

    final showClaimTicketsLabel =
        currentUser?.isSupport == true ||
        currentUser?.isHR == true ||
        currentUser?.isProjectCoordinator == true ||
        currentUser?.isSupportHead == true;
    final showBillsAsDashboard = currentUser?.isAccountant == true;

    final canViewAmcReminder =
        !simplifyNav &&
        (currentUser?.isSupport == true ||
            currentUser?.isHR == true ||
            currentUser?.isProjectCoordinator == true ||
            currentUser?.isSupportHead == true ||
            currentUser?.isAgent == true);
    final canViewPastTickets =
        !simplifyNav &&
        (currentUser?.isSupport == true ||
            currentUser?.isHR == true ||
            currentUser?.isProjectCoordinator == true ||
            currentUser?.isSupportHead == true ||
            currentUser?.isAgent == true);
    final canViewBills =
        !simplifyNav ||
        currentUser?.isAdmin == true ||
        currentUser?.isAccountant == true;
    final canViewSalesOpportunity =
        currentUser?.isSupportHead == true && !simplifyNav;
    final canViewReports =
        enableReports &&
        !simplifyNav &&
        canSeeScreen('reports') &&
        (currentUser?.isAdmin == true ||
            currentUser?.isAccountant == true ||
            currentUser?.isSupportHead == true);
    final canViewDeals =
        enableDeals &&
        !simplifyNav &&
        canSeeScreen('deals') &&
        (currentUser?.isAdmin == true ||
            currentUser?.isAccountant == true ||
            currentUser?.isSupportHead == true);

    final unreadCount = ref.watch(chatUnreadCountProvider);
    final overdueCount = ref.watch(overdueClaimedTicketsProvider).asData?.value.length ?? 0;
    final staleCount = ref.watch(staleUnclaimedTicketsProvider).asData?.value.length ?? 0;
    final alertCount = overdueCount + staleCount;

    // Main navigation items (left side)
    final isSalesChannel = currentPath.startsWith('/sales-channel');
    final mainNavItems = <Widget>[
      if (isSalesChannel) ...[
        _TopNavItem(
          label: 'Chat',
          icon: LucideIcons.messageCircle,
          path: '/sales-channel?tab=0',
          isActive:
              currentPath == '/sales-channel' ||
              currentPath.contains('/sales-channel') &&
                  (GoRouterState.of(context).uri.queryParameters['tab'] ??
                          '0') ==
                      '0',
        ),

        _TopNavItem(
          label: 'Pipeline',
          icon: LucideIcons.layers,
          path: '/sales-channel?tab=2',
          isActive:
              currentPath.contains('/sales-channel') &&
              (GoRouterState.of(context).uri.queryParameters['tab'] ?? '') ==
                  '2',
        ),
      ] else ...[
        _TopNavItem(
          label: 'Chat',
          icon: LucideIcons.messageSquare,
          path: '/chat',
          isActive: currentPath.startsWith('/chat'),
          badgeCount: unreadCount,
        ),

        if (!isRestrictedAgent)
          _TopNavItem(
            label: showBillsAsDashboard
                ? 'Bills'
                : (isSales
                      ? 'Dashboard'
                      : (showClaimTicketsLabel ? 'Tickets' : 'Dashboard')),
            icon: showBillsAsDashboard
                ? LucideIcons.receipt
                : (showClaimTicketsLabel
                      ? LucideIcons.ticket
                      : LucideIcons.layoutDashboard),
            path: showBillsAsDashboard
                ? '/accountant'
                : (isSales
                      ? '/sales'
                      : (currentUser?.isSupport == true ||
                                currentUser?.isHR == true ||
                                currentUser?.isProjectCoordinator == true
                            ? '/support'
                            : '/dashboard')),
            isActive:
                currentPath == '/' ||
                currentPath == '/dashboard' ||
                currentPath == '/admin' ||
                currentPath == '/accountant' ||
                currentPath == '/sales' ||
                currentPath == '/support' ||
                (showClaimTicketsLabel &&
                    (currentPath.startsWith('/tickets') ||
                        currentPath.startsWith('/ticket'))),
          ),
        if (!isRestrictedAgent &&
            currentUser?.isAccountant != true &&
            currentUser?.isSupport != true &&
            currentUser?.isHR != true &&
            currentUser?.isProjectCoordinator != true &&
            currentUser?.isSupportHead != true)
          _TopNavItem(
            label: isSales
                ? 'My Tickets'
                : (isTeleCaller ? 'My Tickets' : 'Tickets'),
            icon: LucideIcons.ticket,
            path: '/tickets',
            isActive:
                currentPath.startsWith('/tickets') ||
                currentPath.startsWith('/ticket'),
          ),
        // Support Dashboard for Accountants
        if (!isRestrictedAgent && currentUser?.isAccountant == true)
          _TopNavItem(
            label: 'Support',
            icon: LucideIcons.headphones,
            path: '/support',
            isActive: currentPath == '/support',
          ),
      ],
    ];

    // Right side utility items (near profile)
    final useGroupedNav =
        currentUser?.isAdmin == true || currentUser?.isAccountant == true;

    final rightNavItems = <Widget>[
      if (enableNotifications)
        _TopNavButton(
          label: 'Alerts',
          icon: LucideIcons.bell,
          badgeCount: alertCount,
          onTap: () {
            context.go('/alerts');
          }
        ),
      if (enableGlobalSearch)
        _TopNavButton(
          label: 'Search',
          icon: LucideIcons.search,
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const _GlobalSearchDialog(),
            );
          },
        ),
      _TopNavButton(
        label: 'Reminder',
        icon: LucideIcons.alarmClock,
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => const AddReminderDialog(),
          );
        },
      ),

      if (!useGroupedNav) ...[
        if (currentUser?.isTeleCaller != true && !isRestrictedAgent)
          _TopNavItem(
            label: 'Customers',
            icon: LucideIcons.users,
            path: '/customers',
            isActive:
                currentPath.startsWith('/customers') ||
                currentPath.startsWith('/customer'),
          ),
        if (canViewAmcReminder)
          _TopNavItem(
            label: 'AMC Reminder',
            icon: LucideIcons.calendarClock,
            path: '/amc-reminder',
            isActive: currentPath.startsWith('/amc-reminder'),
          ),
        if (!isRestrictedAgent &&
            currentUser?.isSoftwareDeveloper != true &&
            (canViewBills || currentUser?.isProjectCoordinator == true) &&
            !showBillsAsDashboard)
          _TopNavItem(
            label: 'Bills',
            icon: LucideIcons.receipt,
            path: '/bills',
            isActive: currentPath.startsWith('/bills'),
          ),
        if (!isRestrictedAgent && canViewPastTickets)
          _TopNavItem(
            label: 'Past Tickets',
            icon: LucideIcons.archive,
            path: '/past-tickets',
            isActive: currentPath == '/past-tickets',
          ),
        if (currentUser?.isAdmin == true || currentUser?.isAccountant == true)
          _TopNavItem(
            label: 'Revenue',
            icon: LucideIcons.indianRupee,
            path: '/revenue',
            isActive: currentPath.startsWith('/revenue'),
          ),
        if (canViewSalesOpportunity)
          _TopNavItem(
            label: 'Sales Opportunity',
            icon: LucideIcons.trendingUp,
            path: '/sales-opportunity',
            isActive: currentPath.startsWith('/sales-opportunity'),
          ),
        if (canViewReports)
          _TopNavItem(
            label: 'Reports',
            icon: LucideIcons.barChart,
            path: '/reports',
            isActive: currentPath.startsWith('/reports'),
          ),
        if (currentUser?.isAdmin == true ||
            currentUser?.isHR == true ||
            currentUser?.id == '326cf09e-ab94-4dd4-bc90-93c41d626b1d')
          _TopNavItem(
            label: 'User Management',
            icon: LucideIcons.users,
            path: '/users',
            isActive: currentPath.startsWith('/users'),
          ),
        if (canViewDeals)
          _TopNavItem(
            label: 'Deals',
            icon: LucideIcons.briefcase,
            path: '/deals',
            isActive: currentPath.startsWith('/deals'),
          ),
        if (currentUser?.isSales == true ||
            currentUser?.isAccountant == true ||
            currentUser?.isAdmin == true)
          _TopNavItem(
            label: 'Leads',
            icon: LucideIcons.target,
            path: '/leads',
            isActive: currentPath.startsWith('/leads'),
          ),
        if (!(currentUser?.isSupport == true ||
                currentUser?.isHR == true ||
                currentUser?.isSupportHead == true) &&
            currentUser?.isTeleCaller != true &&
            currentUser?.isSoftwareDeveloper != true &&
            currentUser?.isDigitalMarketing != true)
          _TopNavItem(
            label: 'Proposals',
            icon: LucideIcons.fileText,
            path: '/proposal-generator',
            isActive: currentPath.startsWith('/proposal-generator'),
          ),
        if (currentUser?.isAdmin == true)
          _TopNavItem(
            label: 'Settings',
            icon: LucideIcons.settings,
            path: '/settings',
            isActive: currentPath.startsWith('/settings'),
          ),
      ] else ...[
        // Grouped Icon Menus for Admin and Accountant
        _TopNavHoverMenu(
          icon: LucideIcons.briefcase,
          tooltip: 'Sales',
          isParentActive:
              currentPath.startsWith('/leads') ||
              currentPath.startsWith('/deals') ||
              currentPath.startsWith('/proposal-generator') ||
              currentPath.startsWith('/customers') ||
              currentPath.startsWith('/customer'),
          items: [
            if (currentUser?.isSales == true ||
                currentUser?.isAccountant == true ||
                currentUser?.isAdmin == true)
              _DropdownItem(
                label: 'Leads',
                icon: LucideIcons.target,
                path: '/leads',
                isActive: currentPath.startsWith('/leads'),
              ),
            if (canViewDeals)
              _DropdownItem(
                label: 'Deals',
                icon: LucideIcons.briefcase,
                path: '/deals',
                isActive: currentPath.startsWith('/deals'),
              ),
            if (!(currentUser?.isSupport == true ||
                    currentUser?.isHR == true ||
                    currentUser?.isSupportHead == true) &&
                currentUser?.isSoftwareDeveloper != true &&
                currentUser?.isDigitalMarketing != true)
              _DropdownItem(
                label: 'Proposals',
                icon: LucideIcons.fileText,
                path: '/proposal-generator',
                isActive: currentPath.startsWith('/proposal-generator'),
              ),
            if (!isRestrictedAgent)
              _DropdownItem(
                label: 'Customers',
                icon: LucideIcons.users,
                path: '/customers',
                isActive:
                    currentPath.startsWith('/customers') ||
                    currentPath.startsWith('/customer'),
              ),
          ],
        ),

        _TopNavHoverMenu(
          icon: LucideIcons.indianRupee,
          tooltip: 'Finance',
          isParentActive:
              currentPath.startsWith('/bills') ||
              currentPath.startsWith('/revenue'),
          items: [
            if (currentUser?.isSoftwareDeveloper != true &&
                canViewBills &&
                !showBillsAsDashboard)
              _DropdownItem(
                label: 'Bills',
                icon: LucideIcons.receipt,
                path: '/bills',
                isActive: currentPath.startsWith('/bills'),
              ),
            if (currentUser?.isAdmin == true ||
                currentUser?.isAccountant == true)
              _DropdownItem(
                label: 'Revenue',
                icon: LucideIcons.indianRupee,
                path: '/revenue',
                isActive: currentPath.startsWith('/revenue'),
              ),
            if (currentUser?.isAccountant == true)
              _DropdownItem(
                label: 'Support',
                icon: LucideIcons.headphones,
                path: '/support',
                isActive: currentPath == '/support',
              ),
          ],
        ),

        if (canViewReports)
          _TopNavHoverMenu(
            icon: LucideIcons.barChart,
            tooltip: 'Analytics',
            isParentActive: currentPath.startsWith('/reports'),
            onDirectTap: () => context.go('/reports'),
          ),

        _TopNavHoverMenu(
          icon: LucideIcons.settings,
          tooltip: 'Administration',
          isParentActive:
              currentPath.startsWith('/users') ||
              currentPath.startsWith('/settings'),
          items: [
            if (currentUser?.isAdmin == true || currentUser?.isHR == true)
              _DropdownItem(
                label: 'User Management',
                icon: LucideIcons.users,
                path: '/users',
                isActive: currentPath.startsWith('/users'),
              ),
            if (currentUser?.isAdmin == true)
              _DropdownItem(
                label: 'Settings',
                icon: LucideIcons.settings,
                path: '/settings',
                isActive: currentPath.startsWith('/settings'),
              ),
          ],
        ),
      ],
    ];

    final themeType = ref.watch(themeProvider);
    final isPinkTheme = themeType == AppThemeType.pink;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isPinkTheme ? AppColors.pinkThemeNav : null,
        gradient: isPinkTheme ? null : const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primaryDark, AppColors.slate900],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    LucideIcons.checkSquare,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TallyCare',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0x1AFFFFFF)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: mainNavItems),
            ),
          ),

          // Right side navigation items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: rightNavItems),
          ),

          // Refresh button - invalidate providers instead of full page reload
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(
                  LucideIcons.refreshCw,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  // Invalidate all data providers to refresh without page reload
                  ref.invalidate(rawTicketsStreamProvider);
                  ref.invalidate(paginatedTicketsProvider);
                  ref.invalidate(allTicketsStreamProvider);
                  ref.invalidate(rawAllTicketsStreamProvider);
                  ref.invalidate(ticketStatsProvider);
                  ref.invalidate(customersListProvider);
                  ref.invalidate(agentsListProvider);
                  ref.invalidate(chatStreamProvider('support-chat'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data refreshed'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: 'Refresh Data',
                padding: const EdgeInsets.all(12),
              );
            },
          ),

          const SizedBox(width: 56, child: _UserProfile()),
        ],
      ),
    );
  }
}

class _GlobalSearchDialog extends ConsumerStatefulWidget {
  const _GlobalSearchDialog();

  @override
  ConsumerState<_GlobalSearchDialog> createState() =>
      _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<_GlobalSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsStreamProvider);
    final customersAsync = ref.watch(customersListProvider);
    final dealsAsync = ref.watch(dealsProvider);
    final leadsAsync = ref.watch(leadsProvider);
    final agentsAsync = ref.watch(agentsListProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 640,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Global Search',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search tickets or customers...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value.trim();
                  });
                },
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Builder(
                    builder: (context) {
                      final isLoading = ticketsAsync.isLoading ||
                          customersAsync.isLoading ||
                          dealsAsync.isLoading ||
                          leadsAsync.isLoading ||
                          agentsAsync.isLoading;

                      if (isLoading && _query.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      final tickets = ticketsAsync.asData?.value ?? [];
                      final customers = customersAsync.asData?.value ?? [];
                      final deals = dealsAsync.asData?.value ?? [];
                      final leads = leadsAsync.asData?.value ?? [];
                      final agents = agentsAsync.asData?.value ?? [];

                      final q = _query.toLowerCase();

                      final ticketResults = q.isEmpty
                          ? <dynamic>[]
                          : tickets
                              .where((t) {
                                final title = t.title.toLowerCase();
                                final id = t.ticketId.toLowerCase();
                                final desc = (t.description ?? '').toString().toLowerCase();
                                return title.contains(q) || id.contains(q) || desc.contains(q);
                              })
                              .take(10)
                              .toList();

                      final customerResults = q.isEmpty
                          ? <dynamic>[]
                          : customers
                              .where((c) {
                                final name = c.companyName.toLowerCase();
                                final apiKey = c.apiKey.toLowerCase();
                                return name.contains(q) || apiKey.contains(q);
                              })
                              .take(10)
                              .toList();

                      final dealResults = q.isEmpty
                          ? <dynamic>[]
                          : deals
                              .where((d) {
                                final name = d.name.toLowerCase();
                                final remark = d.remark.toLowerCase();
                                return name.contains(q) || remark.contains(q);
                              })
                              .take(10)
                              .toList();

                      final leadResults = q.isEmpty
                          ? <dynamic>[]
                          : leads
                              .where((l) {
                                final name = l.companyName.toLowerCase();
                                return name.contains(q);
                              })
                              .take(10)
                              .toList();

                      final agentResults = q.isEmpty
                          ? <dynamic>[]
                          : agents
                              .where((a) {
                                final name = (a['full_name']?.toString() ?? '').toLowerCase();
                                final username = (a['username']?.toString() ?? '').toLowerCase();
                                return name.contains(q) || username.contains(q);
                              })
                              .take(10)
                              .toList();

                      if (ticketResults.isEmpty &&
                          customerResults.isEmpty &&
                          dealResults.isEmpty &&
                          leadResults.isEmpty &&
                          agentResults.isEmpty) {
                        return const Center(
                          child: Text(
                            'Type to search tickets, customers, deals, leads, or agents',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.slate500,
                            ),
                          ),
                        );
                      }

                      return ListView(
                        children: [
                          if (ticketResults.isNotEmpty) ...[
                            const Text(
                              'Tickets',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...ticketResults.map((t) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(LucideIcons.ticket, size: 18, color: AppColors.primary),
                                title: Text(t.title ?? 'Ticket', maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('ID: ${t.ticketId}', style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/ticket/${t.ticketId}');
                                },
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (customerResults.isNotEmpty) ...[
                            const Text(
                              'Customers',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...customerResults.map((c) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(LucideIcons.users, size: 18, color: AppColors.slate700),
                                title: Text(c.companyName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(c.apiKey, style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/customer/${c.id}');
                                },
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (dealResults.isNotEmpty) ...[
                            const Text(
                              'Deals',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...dealResults.map((d) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(LucideIcons.briefcase, size: 18, color: AppColors.success),
                                title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(d.remark, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/deals');
                                },
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (leadResults.isNotEmpty) ...[
                            const Text(
                              'Leads',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...leadResults.map((l) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(LucideIcons.target, size: 18, color: AppColors.warning),
                                title: Text(l.companyName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('Amount: ${l.amount}', style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/leads');
                                },
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (agentResults.isNotEmpty) ...[
                            const Text(
                              'Agents',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...agentResults.map((a) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(LucideIcons.user, size: 18, color: AppColors.primary),
                                title: Text(a['full_name']?.toString() ?? 'Agent', maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('@${a['username'] ?? ''} - ${a['role'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/users'); // No direct user page, go to users list
                                },
                              );
                            }),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopNavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final String path;
  final bool isActive;
  final int badgeCount;

  const _TopNavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.isActive,
    this.badgeCount = 0,
  });

  @override
  State<_TopNavItem> createState() => _TopNavItemState();
}

class _TopNavItemState extends State<_TopNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withValues(alpha: 0.72);
    final activeColor = AppColors.primaryLight;
    final itemColor = widget.isActive
        ? activeColor.withValues(alpha: 0.16)
        : (_isHovered
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(widget.path),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(8),
                border: widget.isActive
                    ? Border.all(
                        color: activeColor.withValues(alpha: 0.32),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 17,
                    color: widget.isActive ? activeColor : inactiveColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: widget.isActive ? Colors.white : inactiveColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.badgeCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        widget.badgeCount > 9
                            ? '9+'
                            : widget.badgeCount.toString(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _TopNavButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  Badge(
                    label: Text(badgeCount.toString()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownItem {
  final String label;
  final IconData icon;
  final String path;
  final bool isActive;
  final VoidCallback? onTap;

  _DropdownItem({
    required this.label,
    required this.icon,
    this.path = '',
    this.isActive = false,
    this.onTap,
  });
}

class _TopNavHoverMenu extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final List<_DropdownItem> items;
  final bool isParentActive;
  final VoidCallback? onDirectTap;

  const _TopNavHoverMenu({
    super.key,
    required this.icon,
    required this.tooltip,
    this.items = const [],
    this.isParentActive = false,
    this.onDirectTap,
  });

  @override
  State<_TopNavHoverMenu> createState() => _TopNavHoverMenuState();
}

class _TopNavHoverMenuState extends State<_TopNavHoverMenu>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isMenuHovered = false;
  OverlayEntry? _overlayEntry;
  final GlobalKey _key = GlobalKey();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _checkAndHide() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isHovered && !_isMenuHovered && mounted) {
        _animController.reverse().then((_) {
          if (mounted && !_isHovered && !_isMenuHovered) {
            _removeOverlay();
          }
        });
      }
    });
  }

  void _showOverlay() {
    if (widget.items.isEmpty) return;
    if (_overlayEntry != null) return;

    final RenderBox renderBox =
        _key.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        const dropdownWidth = 200.0;
        double leftPos = offset.dx;
        
        // Prevent dropdown from rendering off-screen on the right edge
        if (leftPos + dropdownWidth > screenWidth) {
          leftPos = screenWidth - dropdownWidth - 16; // 16px padding
        }

        return Positioned(
          left: leftPos,
          top: offset.dy + size.height,
          child: MouseRegion(
            onEnter: (_) {
              _isMenuHovered = true;
            },
            onExit: (_) {
              _isMenuHovered = false;
              _checkAndHide();
            },
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.only(top: 8), // Gap bridge
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    width: 200,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.items.map((item) {
                        return InkWell(
                          onTap: () {
                            _removeOverlay();
                            if (item.onTap != null) {
                              item.onTap!();
                            } else if (item.path.isNotEmpty) {
                              context.go(item.path);
                            }
                          },
                          hoverColor: Colors.white.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 16,
                                  color: item.isActive
                                      ? AppColors.primaryLight
                                      : Colors.white.withValues(alpha: 0.72),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: item.isActive
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.8),
                                    fontWeight: item.isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.onDirectTap == null)
      return const SizedBox.shrink();

    Widget iconWidget = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isParentActive
            ? AppColors.primaryLight.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        widget.icon,
        color: widget.isParentActive
            ? AppColors.primaryLight
            : Colors.white.withValues(alpha: 0.72),
        size: 20,
      ),
    );

    if (widget.items.isEmpty) {
      iconWidget = Tooltip(
        message: widget.tooltip,
        child: iconWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: MouseRegion(
        onEnter: (_) {
          _isHovered = true;
          if (widget.items.isNotEmpty) {
            _showOverlay();
          }
        },
        onExit: (_) {
          _isHovered = false;
          if (widget.items.isNotEmpty) {
            _checkAndHide();
          }
        },
        child: InkWell(
          key: _key,
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (widget.items.isEmpty && widget.onDirectTap != null) {
              widget.onDirectTap!();
            }
          },
          child: iconWidget,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final String path;
  final bool isActive;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.isActive,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withValues(alpha: 0.6);
    final hoverColor = Colors.white.withValues(alpha: 0.08);
    final activeColor = AppColors.primaryLight;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(widget.path),
            borderRadius: BorderRadius.circular(8),
            splashColor: Colors.white.withValues(alpha: 0.1),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? activeColor.withValues(alpha: 0.15)
                    : (_isHovered ? hoverColor : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: widget.isActive
                    ? Border.all(
                        color: activeColor.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          size: 18,
                          color: widget.isActive ? activeColor : inactiveColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: widget.isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: widget.isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final String currentPath;

  const _BottomNav({required this.currentPath});

  void _showMoreMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final currentUser = ref.watch(authProvider);
        final isAccountant = currentUser?.isAccountant == true;
        final isAdmin = currentUser?.isAdmin == true;
        final isSupportHead = currentUser?.isSupportHead == true;
        
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text('More Options', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(LucideIcons.bell, color: Colors.white),
                  title: const Text('Activity', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); context.go('/alerts'); },
                ),
                if (!isAccountant && !isAdmin && currentUser?.isSupport != true)
                  ListTile(
                    leading: const Icon(LucideIcons.layoutDashboard, color: Colors.white),
                    title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); context.go('/dashboard'); },
                  ),
                if (isAdmin || isAccountant)
                  ListTile(
                    leading: const Icon(LucideIcons.layoutDashboard, color: Colors.white),
                    title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); context.go(isAdmin ? '/admin' : '/accountant'); },
                  ),
                ListTile(
                  leading: const Icon(LucideIcons.ticket, color: Colors.white),
                  title: const Text('Tickets', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); context.go('/tickets'); },
                ),
                if (currentUser?.isSales == true || isAdmin || isAccountant)
                  ListTile(
                    leading: const Icon(LucideIcons.target, color: Colors.white),
                    title: const Text('Leads', style: TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); context.go('/leads'); },
                  ),
                if (isAdmin || isAccountant || isSupportHead)
                  ListTile(
                    leading: const Icon(LucideIcons.briefcase, color: Colors.white),
                    title: const Text('Deals', style: TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); context.go('/deals'); },
                  ),
                if (isAdmin || isAccountant)
                  ListTile(
                    leading: const Icon(LucideIcons.indianRupee, color: Colors.white),
                    title: const Text('Revenue', style: TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); context.go('/revenue'); },
                  ),
                ListTile(
                  leading: const Icon(LucideIcons.users, color: Colors.white),
                  title: const Text('Customers', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); context.go('/customers'); },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.barChart3, color: Colors.white),
                  title: const Text('Reports', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); context.go('/reports'); },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.fileText, color: Colors.white),
                  title: const Text('Proposals', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); context.go('/proposal-generator'); },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    final isPinkTheme = themeType == AppThemeType.pink;
    final isWhiteTheme = themeType == AppThemeType.white;
    final isLight = isWhiteTheme;

    final int totalDmUnread = ref.watch(dmConversationsProvider.select<int>((map) => map.values.fold<int>(0, (sum, conv) => sum + conv.unreadCount)));
    final int aggregateUnread = (ref.watch(chatUnreadCountProvider) + ref.watch(allAroundTallyUnreadCountProvider) + totalDmUnread).toInt();

    final bgColor = isLight 
        ? Colors.white 
        : const Color(0xFF1A1D21);
    
    final isSalesChannel = currentPath.startsWith('/sales-channel');

    final unselectedColor = isLight ? Colors.black54 : Colors.white.withValues(alpha: 0.6);
    final selectedColor = isLight 
        ? (isPinkTheme ? AppColors.pinkThemeSidebar : AppColors.primary)
        : Colors.white;

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(LucideIcons.home, color: unselectedColor),
        selectedIcon: Icon(LucideIcons.home, color: selectedColor),
        label: 'Home',
      ),
      if (isSalesChannel) ...[
        NavigationDestination(
          icon: Icon(LucideIcons.messageCircle, color: unselectedColor),
          selectedIcon: Icon(LucideIcons.messageCircle, color: selectedColor),
          label: 'Sales Chat',
        ),
        NavigationDestination(
          icon: Icon(LucideIcons.layers, color: unselectedColor),
          selectedIcon: Icon(LucideIcons.layers, color: selectedColor),
          label: 'Pipeline',
        ),
      ] else ...[
        NavigationDestination(
          icon: aggregateUnread > 0
              ? Badge(
                  label: Text(aggregateUnread > 9 ? '9+' : aggregateUnread.toString()),
                  child: Icon(LucideIcons.messageCircle, color: unselectedColor),
                )
              : Icon(LucideIcons.messageCircle, color: unselectedColor),
          selectedIcon: aggregateUnread > 0
              ? Badge(
                  label: Text(aggregateUnread > 9 ? '9+' : aggregateUnread.toString()),
                  child: Icon(LucideIcons.messageCircle, color: selectedColor),
                )
              : Icon(LucideIcons.messageCircle, color: selectedColor),
          label: 'Chat',
        ),
      ],
      if (!isSalesChannel)
        NavigationDestination(
          icon: Icon(LucideIcons.search, color: unselectedColor),
          selectedIcon: Icon(LucideIcons.search, color: selectedColor),
          label: 'Search',
        ),
      NavigationDestination(
        icon: Icon(Icons.more_horiz, color: unselectedColor),
        selectedIcon: Icon(Icons.more_horiz, color: selectedColor),
        label: 'More',
      ),
    ];
    
    final navRoutes = isSalesChannel
        ? ['/mobile-home', '/sales-channel?tab=0', '/sales-channel?tab=2', '__more__']
        : ['/mobile-home', '/chat', '__search__', '__more__'];
    
    int selectedIndex = 0;
    if (currentPath == '/mobile-home') {
      selectedIndex = 0;
    } else if (isSalesChannel) {
      final tab = GoRouterState.of(context).uri.queryParameters['tab'] ?? '0';
      if (tab == '0') selectedIndex = 1;
      else if (tab == '2') selectedIndex = 2;
      else selectedIndex = 1; 
    } else if (currentPath.startsWith('/chat')) {
      selectedIndex = 1;
    } else if (currentPath.startsWith('/alerts') || 
               currentPath.startsWith('/tickets') ||
               currentPath.startsWith('/leads') ||
               currentPath.startsWith('/deals') ||
               currentPath.startsWith('/revenue') ||
               currentPath.startsWith('/customers') ||
               currentPath.startsWith('/reports') ||
               currentPath.startsWith('/proposal-generator')) {
      selectedIndex = 3;
    }

    final indicatorColor = isLight 
        ? (isPinkTheme 
            ? AppColors.pinkThemeSidebar.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.12))
        : Colors.white.withValues(alpha: 0.12);
    
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight 
                ? AppColors.border 
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: indicatorColor,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(color: selectedColor, fontSize: 12, fontWeight: FontWeight.bold);
              }
              return TextStyle(color: unselectedColor, fontSize: 12);
            }),
          ),
          child: NavigationBar(
            height: 60,
            elevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: selectedIndex >= 0 && selectedIndex < destinations.length ? selectedIndex : 0,
            onDestinationSelected: (index) {
              final route = navRoutes[index];
              if (route == '__search__') {
                showDialog(
                  context: context,
                  builder: (context) => const _GlobalSearchDialog(),
                );
              } else if (route == '__more__') {
                _showMoreMenu(context, ref);
              } else {
                context.go(route);
              }
            },
            destinations: destinations,
          ),
          ),
        ),
      ),
      ),
    );
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityStatusProvider);

    return connectivityAsync.when(
      data: (status) {
        final isOffline = status == ConnectivityResult.none;

        if (!isOffline) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: const Text(
            'You are offline. Some features may be unavailable.',
            style: TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _UserProfile extends ConsumerWidget {
  const _UserProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return PopupMenuButton<int>(
      tooltip: '${currentUser?.fullName ?? 'User'} (${currentUser?.role ?? 'Role'})',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary,
        backgroundImage: currentUser?.avatarUrl != null
            ? NetworkImage(currentUser!.avatarUrl!)
            : null,
        child: currentUser?.avatarUrl == null
            ? Text(
                currentUser?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            : null,
      ),
      onSelected: (value) {
        if (value == 0) {
          context.go('/profile');
        } else if (value == 1) {
          final currentTheme = ref.read(themeProvider);
          final nextTheme = currentTheme == AppThemeType.white
              ? AppThemeType.blueGradient
              : AppThemeType.white;
          ref.read(themeProvider.notifier).setTheme(nextTheme);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              Icon(LucideIcons.user, size: 18, color: AppColors.slate700),
              SizedBox(width: 12),
              Text('My Profile'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(isDark ? LucideIcons.moon : LucideIcons.sun, size: 18, color: AppColors.slate700),
              const SizedBox(width: 12),
              const Expanded(child: Text('Dark Mode')),
              IgnorePointer(
                child: Switch(
                  value: isDark,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -- Left Navigation (Empty for Support Chat) -------------------------------


// -- Mobile Home Page --------------------------------------------------------

class MobileHomePage extends ConsumerWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    // If resized to desktop while on mobile home, redirect to root
    if (isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final currentUser = ref.watch(authProvider);
    final themeType = ref.watch(themeProvider);
    final isPinkTheme = themeType == AppThemeType.pink;
    final isWhiteTheme = themeType == AppThemeType.white;
    final isLight = isWhiteTheme;
    
    // Background color of body: white for light theme, dark gray for dark theme
    final bgColor = isWhiteTheme ? Colors.white : const Color(0xFF1A1D21); 
    
    final appBarBgColor = isWhiteTheme 
        ? Colors.white 
        : (isPinkTheme ? AppColors.pinkThemeNav : const Color(0xFF1A1D21));
    final topBarTextColor = isWhiteTheme ? Colors.black87 : Colors.white;
    final topBarIconColor = isWhiteTheme ? Colors.black87 : Colors.white.withValues(alpha: 0.8);
    final topBarButtonBg = isWhiteTheme ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.15);

    return MainLayout(
      currentPath: '/mobile-home',
      child: Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: SafeArea(
            child: Container(
              margin: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: appBarBgColor.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ),
          leadingWidth: 54,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 12.0),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: topBarButtonBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'SI',
                style: TextStyle(
                  color: topBarTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Sidharth IT Solutions',
                  style: TextStyle(
                    color: topBarTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                color: topBarIconColor,
                size: 20,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () => context.go('/profile'),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: topBarButtonBg,
                  backgroundImage: currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty
                      ? NetworkImage(currentUser.avatarUrl!)
                      : null,
                  child: currentUser?.avatarUrl == null || currentUser!.avatarUrl!.isEmpty
                      ? Icon(LucideIcons.user, size: 18, color: topBarTextColor)
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: const _LeftNav(currentPath: '/mobile-home'),
      ),
    );
  }
}

class _LeftNav extends ConsumerWidget {
  final String currentPath;

  const _LeftNav({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    final isPinkTheme = themeType == AppThemeType.pink;
    final isWhiteTheme = themeType == AppThemeType.white;
    final isLight = isWhiteTheme;

    final isMobile = MediaQuery.of(context).size.width <= 900;
    
    return Container(
      decoration: BoxDecoration(
        color: (isMobile && isLight)
            ? Colors.white
            : (isPinkTheme && !isMobile ? AppColors.pinkThemeSidebar : null),
        gradient: (isMobile && isLight) || isPinkTheme
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
      child: SafeArea(
        top: !isMobile,
        bottom: false,
        child: Column(
          children: [
            // Channels and DMs section
            Expanded(child: _ChannelsList(currentPath: currentPath)),
          ],
        ),
      ),
    );
  }
}

// -- Resize Handle Widget ----------------------------------------------------

class _ResizeHandle extends StatefulWidget {
  final Function(double) onDrag;

  const _ResizeHandle({required this.onDrag});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (details) {
          widget.onDrag(details.delta.dx);
        },
        onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
        child: Container(
          width: 4,
          decoration: BoxDecoration(
            color: _isHovering || _isDragging
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.transparent,
            border: Border(
              right: BorderSide(
                color: _isHovering || _isDragging
                    ? AppColors.primary
                    : AppColors.border,
                width: _isHovering || _isDragging ? 2 : 1,
              ),
            ),
          ),
          child: _isHovering || _isDragging
              ? Center(
                  child: Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// -- Collapsible Ticket Pane -------------------------------------------------

class _CollapsibleTicketPane extends ConsumerWidget {
  final String currentPath;
  final bool isOpen;
  final VoidCallback onToggle;

  const _CollapsibleTicketPane({
    required this.currentPath,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(ticketsStreamProvider);

    final tickets = ticketsAsync.value ?? [];
    final now = DateTime.now();
    final twoDaysAgo = now.subtract(const Duration(days: 2));
    final recentTickets = tickets
        .where((t) => t.createdAt != null && t.createdAt!.isAfter(twoDaysAgo))
        .toList();

    // ignore: unused_local_variable
    final unclaimedCount = recentTickets
        .where((t) => t.assignedTo == null || t.assignedTo!.isEmpty)
        .length;
    // ignore: unused_local_variable
    final claimedCount = recentTickets
        .where((t) => t.assignedTo != null && t.assignedTo!.isNotEmpty)
        .where(
          (t) =>
              t.status != 'Resolved' &&
              t.status != 'Closed' &&
              t.status != 'BillRaised' &&
              t.status != 'BillProcessed',
        )
        .length;
    // ignore: unused_local_variable
    final resolvedCount = recentTickets
        .where(
          (t) =>
              t.status == 'Resolved' ||
              t.status == 'Closed' ||
              t.status == 'BillRaised' ||
              t.status == 'BillProcessed',
        )
        .length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Collapsed arrow strip — only visible when pane is closed
        if (!isOpen)
          Consumer(
            builder: (context, ref, _) {
              final isPinkTheme = ref.watch(themeProvider) == AppThemeType.pink;
              return Container(
                width: 24,
                decoration: BoxDecoration(
                  color: isPinkTheme ? AppColors.pinkThemeSidebar : null,
                  gradient: isPinkTheme ? null : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryDark, AppColors.slate900],
                  ),
              border: Border(
                right: BorderSide(color: Color(0x1AFFFFFF), width: 1),
              ),
            ),
            child: Center(
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    LucideIcons.chevronsRight,
                    size: 16,
                    color: Colors.white54,
                  ),
                ),
              ),
              ),
            );
          },
        ),
        // Expanded pane — animated
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: isOpen ? 240 : 0,
          child: isOpen
              ? _SecondLeftNav(currentPath: currentPath, onCollapse: onToggle)
              : const SizedBox.shrink(),
        ),
        if (isOpen) const VerticalDivider(width: 1, color: AppColors.border),
      ],
    );
  }
}

// -- Second Left Navigation (Additional Pane) -------------------------------

class _SecondLeftNav extends ConsumerWidget {
  final String currentPath;
  final VoidCallback? onCollapse;

  const _SecondLeftNav({required this.currentPath, this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSalesChannel = currentPath.startsWith('/sales-channel');
    final sectionTitle = isSalesChannel ? 'Recent Sales' : 'Recent Tickets';

    final themeType = ref.watch(themeProvider);
    final isPinkTheme = themeType == AppThemeType.pink;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isPinkTheme ? AppColors.pinkThemeSidebar : null,
        gradient: isPinkTheme ? null : const LinearGradient(
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
      child: Column(
        children: [
          // Recent tickets/sales section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sectionTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onCollapse != null)
                  InkWell(
                    onTap: onCollapse,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        LucideIcons.chevronsLeft,
                        size: 16,
                        color: Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x1AFFFFFF)),
          Expanded(
            child: isSalesChannel
                ? const _RecentSalesPlaceholder()
                : _RecentTicketsList(),
          ),
        ],
      ),
    );
  }
}

class _ChannelsList extends ConsumerStatefulWidget {
  final String currentPath;

  const _ChannelsList({required this.currentPath});

  @override
  ConsumerState<_ChannelsList> createState() => _ChannelsListState();
}

class _ChannelsListState extends ConsumerState<_ChannelsList> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = widget.currentPath;
    final isChatActive = currentPath == '/chat';
    final agentsAsync = ref.watch(agentsListProvider);
    final conversations = ref.watch(dmConversationsProvider);
    final currentUser = ref.watch(authProvider);
    final customChannelsAsync = ref.watch(customChannelsProvider);

    const allowedSalesChannelIds = {
      '14db36db-0cb9-44ef-8032-d9610b3bc797',
      'b77b3738-4dfc-4515-a1fd-d6fb170423f4',
      'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c',
      '5a06a8df-97f1-4dbf-bc13-9724a3c779c1',
      'd9572a84-762b-4c8b-8ef5-7da0345e3ea8',
      '0a5aeeb8-9544-4dc8-920f-e26c192b0dd3',
      'f3b54de6-0372-4648-ad87-3e98089efc2d',
    };
    const allowedAroundTallyChannelIds = {
      'd7a9e726-9520-4cc8-95a6-b38a4afd1d7b',
      'dedce60a-56bd-49fd-bbe2-f88534b8e36f',
    };
    final isRestrictedAgent = allowedAroundTallyChannelIds.contains(
      currentUser?.id ?? '',
    );
    final canAccessSalesChannel =
        allowedSalesChannelIds.contains(currentUser?.id ?? '') &&
        !isRestrictedAgent;
    final canAccessDealsTracker =
        currentUser?.id == '0a5aeeb8-9544-4dc8-920f-e26c192b0dd3';
    final restrictedFromAroundAi = {
      'd7a9e726-9520-4cc8-95a6-b38a4afd1d7b',
      'dedce60a-56bd-49fd-bbe2-f88534b8e36f',
    }.contains(currentUser?.id ?? '');

    final isMobile = MediaQuery.of(context).size.width <= 900;
    final themeType = ref.watch(themeProvider);
    final isPinkTheme = themeType == AppThemeType.pink;
    final isWhiteTheme = themeType == AppThemeType.white;
    final isLight = isWhiteTheme;

    // Adaptive colors
    final textColorPrimary = isMobile && isLight ? Colors.black87 : Colors.white;
    final textColor70 = isMobile && isLight ? Colors.black87 : Colors.white70;
    final textColor54 = isMobile && isLight ? Colors.black54 : Colors.white54;
    final activeBgColor = isMobile && isLight
        ? (isPinkTheme
            ? AppColors.pinkThemeSidebar.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.12))
        : Colors.white.withValues(alpha: 0.1);

    return SingleChildScrollView(
      padding: isMobile 
          ? const EdgeInsets.only(top: 80, bottom: 140) 
          : EdgeInsets.zero,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [


        // Channels Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.hash, size: 14, color: textColor70),
                  const SizedBox(width: 8),
                  Text(
                    'Channels',
                    style: TextStyle(
                      color: textColor70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(LucideIcons.plus, size: 16, color: textColor70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const CreateChannelDialog(),
                  );
                },
              ),
            ],
          ),
        ),
        
        // Dynamic Channels
        if (customChannelsAsync.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Error: ${customChannelsAsync.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ),
        if (customChannelsAsync.hasValue) ...[
          for (final channel in customChannelsAsync.value!)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/c/${channel.id}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentPath.startsWith('/c/${channel.id}')
                        ? activeBgColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        channel.isPrivate ? LucideIcons.lock : LucideIcons.hash,
                        size: 16,
                        color: currentPath.startsWith('/c/${channel.id}') ? textColorPrimary : textColor54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channel.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: currentPath.startsWith('/c/${channel.id}') ? textColorPrimary : textColor70,
                            fontSize: 13,
                            fontWeight: currentPath.startsWith('/c/${channel.id}')
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],

        // Support Chat Channel
        Consumer(
          builder: (context, ref, child) {
            final unreadCount = ref.watch(chatUnreadCountProvider);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/chat'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isChatActive
                        ? activeBgColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.hash,
                        size: 16,
                        color: isChatActive ? textColorPrimary : textColor54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'support-chat',
                        style: TextStyle(
                          color: (isChatActive || unreadCount > 0) ? textColorPrimary : textColor70,
                          fontSize: 13,
                          fontWeight: (isChatActive || unreadCount > 0)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99
                                ? '99+'
                                : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Sales Channel
        if (canAccessSalesChannel)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/sales-channel'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: currentPath.startsWith('/sales-channel')
                      ? activeBgColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.hash,
                      size: 16,
                      color: currentPath.startsWith('/sales-channel')
                          ? textColorPrimary
                          : textColor54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'sales',
                      style: TextStyle(
                        color: currentPath.startsWith('/sales-channel')
                            ? textColorPrimary
                            : textColor70,
                        fontSize: 13,
                        fontWeight: currentPath.startsWith('/sales-channel')
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Deals Tracker Channel
        if (canAccessDealsTracker)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/deals-tracker'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: currentPath.startsWith('/deals-tracker')
                      ? activeBgColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.hash,
                      size: 16,
                      color: currentPath.startsWith('/deals-tracker')
                          ? textColorPrimary
                          : textColor54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'deals-tracker',
                      style: TextStyle(
                        color: currentPath.startsWith('/deals-tracker')
                            ? textColorPrimary
                            : textColor70,
                        fontSize: 13,
                        fontWeight: currentPath.startsWith('/deals-tracker')
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // All-AroundTally Channel - accessible to all users
        Consumer(
          builder: (context, ref, child) {
            // Keep the stream alive so unread count updates even when not on the page
            ref.watch(chatStreamProvider(kAllAroundTallyChannel));
            final aroundTallyUnread = ref.watch(
              allAroundTallyUnreadCountProvider,
            );
            final isOnChannel = currentPath.startsWith(
              '/channel/all-aroundtally',
            );
            final displayUnread = isOnChannel ? 0 : aroundTallyUnread;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/channel/all-aroundtally'),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOnChannel
                        ? activeBgColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.hash,
                        size: 16,
                        color: isOnChannel ? textColorPrimary : textColor54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'all-aroundtally',
                        style: TextStyle(
                          color: (isOnChannel || displayUnread > 0)
                              ? textColorPrimary
                              : textColor70,
                          fontSize: 13,
                          fontWeight: (isOnChannel || displayUnread > 0)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (displayUnread > 0) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            displayUnread > 99
                                ? '99+'
                                : displayUnread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),

          // Calls Sidebar Item
          Builder(
            builder: (context) {
              final isCallsActive = currentPath.startsWith('/calls');
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/calls'),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCallsActive ? activeBgColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.phone,
                          size: 16,
                          color: isCallsActive ? textColorPrimary : textColor54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Calls',
                          style: TextStyle(
                            color: isCallsActive ? textColorPrimary : textColor70,
                            fontSize: 13,
                            fontWeight: isCallsActive ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),

          const SizedBox(height: 16),
          // Direct Messages Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(
                  LucideIcons.messagesSquare,
                  size: 14,
                  color: textColor70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct messages',
                    style: TextStyle(
                      color: textColor70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Add New DM button
                IconButton(
                  icon: Icon(LucideIcons.plus, size: 16, color: textColor70),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const NewDmDialog(),
                    );
                  },
                ),
              ],
            ),
          ),
          // Agents List
          agentsAsync.when(
              data: (agents) {
                // Filter out specific agents and those without conversations
                final hiddenAgentIds = const {
                  '2d58eb0a-916a-4cb6-9245-b5b124caa0a3',
                };
                final filteredAgents = agents.where((a) {
                  final id = a['id']?.toString() ?? '';
                  if (hiddenAgentIds.contains(id)) return false;
                  
                  if (isMobile) {
                    final name = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
                    if (name.contains('abhirami') || name.contains('thaness')) return false;
                  }
                  
                  // Only show agents that have an active conversation or are the current user
                  if (currentUser != null && id != currentUser.id) {
                    final conv = conversations[id];
                    if (conv == null || conv.totalMessageCount == 0) {
                      return false;
                    }
                  }
                  
                  return true;
                }).toList();

                // Sort agents: own chat first, then unread, then recent message timestamp, then frequency
                final sortedAgents = List.from(filteredAgents)
                  ..sort((a, b) {
                    final agentAId = a['id']?.toString() ?? '';
                    final agentBId = b['id']?.toString() ?? '';

                    if (currentUser != null) {
                      if (agentAId == currentUser.id && agentBId != currentUser.id) return -1;
                      if (agentBId == currentUser.id && agentAId != currentUser.id) return 1;
                    }

                    final unreadA = conversations[agentAId]?.unreadCount ?? 0;
                    final unreadB = conversations[agentBId]?.unreadCount ?? 0;
                    if (unreadA > 0 && unreadB == 0) return -1;
                    if (unreadB > 0 && unreadA == 0) return 1;

                    final convA = conversations[agentAId];
                    final convB = conversations[agentBId];
                    
                    final countA = convA?.totalMessageCount ?? 0;
                    final countB = convB?.totalMessageCount ?? 0;
                    
                    if (countA != countB) {
                      return countB.compareTo(countA); // Sort by highest message count first
                    }

                    final lastA = convA?.lastMessage?.createdAt;
                    final lastB = convB?.lastMessage?.createdAt;

                    if (lastA != null && lastB != null) {
                      final timeComp = lastB.compareTo(lastA);
                      if (timeComp != 0) return timeComp;
                    } else if (lastA != null) {
                      return -1;
                    } else if (lastB != null) {
                      return 1;
                    }

                    final nameA = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
                    final nameB = (b['full_name'] ?? b['username'] ?? '').toString().toLowerCase();
                    return nameA.compareTo(nameB);
                  });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: sortedAgents.length,
                  itemBuilder: (context, index) {
                    final agent = sortedAgents[index];
                    final agentId = agent['id']?.toString() ?? '';
                    return _SidebarDmTile(
                      key: ValueKey(agentId),
                      agent: agent,
                      index: index,
                      currentPath: widget.currentPath,
                      isMobile: isMobile,
                      isLight: isLight,
                      textColor70: textColor70,
                      activeBgColor: activeBgColor,
                    );
                  },
                );
              },
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => Center(
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor54,
                  ),
                ),
              ),
              error: (err, stack) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Failed to load agents',
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
              ),
            ),
      ],
    ));
  }
}

class _SidebarDmTile extends ConsumerWidget {
  final Map<String, dynamic> agent;
  final int index;
  final String currentPath;
  final bool isMobile;
  final bool isLight;
  final Color textColor70;
  final Color activeBgColor;

  const _SidebarDmTile({
    Key? key,
    required this.agent,
    required this.index,
    required this.currentPath,
    required this.isMobile,
    required this.isLight,
    required this.textColor70,
    required this.activeBgColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final agentId = agent['id']?.toString() ?? '';
    final isCurrentUser = currentUser?.id == agentId;
    final name = isCurrentUser ? 'YOU' : (agent['full_name'] ?? 'Unknown');
    final unreadCount = ref.watch(dmUnreadCountProvider(agentId));

    final lastSeen = agent['last_seen'] != null
        ? DateTime.tryParse(agent['last_seen'].toString())
        : null;
    final now = DateTime.now();

    final isOnline = lastSeen != null && now.difference(lastSeen).inMinutes < 5;
    final isAway = lastSeen != null && !isOnline && now.difference(lastSeen).inMinutes < 30;

    final List<Color> avatarColors = [
      Colors.red.shade400,
      Colors.blue.shade400,
      Colors.green.shade500,
      Colors.orange.shade500,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.indigo.shade400,
    ];
    final avatarColor = avatarColors[index % avatarColors.length];
    final isSelected = currentPath == '/chat/dm/$agentId';

    return Material(
      color: isSelected ? activeBgColor : Colors.transparent,
      child: InkWell(
        onTap: () {
          context.go('/chat/dm/${agent['id']}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTapUp: (details) {
                  final avatarUrl = agent['avatar_url'] as String?;
                  showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      details.globalPosition.dx + 1,
                      details.globalPosition.dy + 1,
                    ),
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    items: [
                      PopupMenuItem(
                        enabled: avatarUrl != null,
                        onTap: avatarUrl != null
                            ? () => _showProfilePicture(context, name, avatarUrl, avatarColor)
                            : null,
                        child: Row(
                          children: [
                            Icon(LucideIcons.userCircle2, size: 16,
                                color: avatarUrl != null ? Colors.white : Colors.white38),
                            const SizedBox(width: 10),
                            Text('View Profile Picture',
                                style: TextStyle(
                                    color: avatarUrl != null ? Colors.white : Colors.white38,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () => context.go('/chat/dm/${agent['id']}'),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.messageSquare, size: 16, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Send Message',
                                style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: avatarColor,
                      backgroundImage: agent['avatar_url'] != null
                          ? NetworkImage(agent['avatar_url'])
                          : null,
                      child: agent['avatar_url'] == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.green
                              : isAway
                              ? Colors.orange
                              : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isMobile && isLight ? Colors.white : AppColors.slate900,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? (isLight ? AppColors.slate900 : Colors.white) : textColor70,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99
                              ? '99+'
                              : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Recent Sales Placeholder Widget -------------------------------------------

class _RecentSalesPlaceholder extends StatelessWidget {
  const _RecentSalesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Sales history coming soon',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }
}

// -- Profile Picture Viewer -----------------------------------------------

void _showProfilePicture(
  BuildContext context,
  String name,
  String avatarUrl,
  Color fallbackColor,
) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name label
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Avatar - large circle
          CircleAvatar(
            radius: 120,
            backgroundColor: fallbackColor,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(height: 24),
          // Close button
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// -- Recent Tickets List Widget -------------------------------------------

class _RecentTicketsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(ticketsStreamProvider);

    return ticketsAsync.when(
      data: (tickets) {
        print('DEBUG: Total tickets: ${tickets.length}');

        // Filter tickets from last 2 days
        final now = DateTime.now();
        final twoDaysAgo = now.subtract(const Duration(days: 2));

        final recentTickets = tickets.where((ticket) {
          if (ticket.createdAt == null) return false;
          final isUnclaimed =
              ticket.assignedTo == null || ticket.assignedTo!.isEmpty;
          return ticket.createdAt!.isAfter(twoDaysAgo) || isUnclaimed;
        }).toList();

        print('DEBUG: Recent tickets (last 2 days): ${recentTickets.length}');

        // Sort: unclaimed first, then by created date (newest first)
        recentTickets.sort((a, b) {
          final aClaimed = a.assignedTo != null && a.assignedTo!.isNotEmpty;
          final bClaimed = b.assignedTo != null && b.assignedTo!.isNotEmpty;

          if (aClaimed != bClaimed) {
            return aClaimed ? 1 : -1; // Unclaimed first
          }

          // Both have same claim status, sort by date
          return (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          );
        });

        if (recentTickets.isEmpty) {
          // If no recent tickets, show some older unclaimed tickets
          final olderUnclaimed = tickets
              .where((ticket) {
                if (ticket.createdAt == null) return false;
                final isClaimed =
                    ticket.assignedTo != null && ticket.assignedTo!.isNotEmpty;
                return !isClaimed; // Show unclaimed tickets regardless of age
              })
              .take(5)
              .toList();

          if (olderUnclaimed.isNotEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'No recent tickets. Showing older unclaimed:',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: olderUnclaimed.length,
                    itemBuilder: (context, index) {
                      final ticket = olderUnclaimed[index];
                      return _TicketTile(ticket: ticket);
                    },
                  ),
                ),
              ],
            );
          }

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No tickets found',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: recentTickets.length,
          itemBuilder: (context, index) {
            final ticket = recentTickets[index];
            return _TicketTile(ticket: ticket);
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Error: $error',
            style: const TextStyle(color: Colors.red, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// -- Ticket Tile Widget -----------------------------------------------------

class _TicketTile extends ConsumerWidget {
  final Ticket ticket;

  const _TicketTile({required this.ticket});

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 2) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _getTicketDescription(Ticket ticket) {
    // Use title as primary issue description
    String description = ticket.title;

    // Add description if available and different from title
    if (ticket.description != null &&
        ticket.description!.isNotEmpty &&
        ticket.description != ticket.title) {
      description += '\n\n${ticket.description}';
    }

    // Add category if available
    if (ticket.category != null && ticket.category!.isNotEmpty) {
      description += '\n\nCategory: ${ticket.category}';
    }

    // Add priority if available
    if (ticket.priority != null && ticket.priority!.isNotEmpty) {
      description += '\nPriority: ${ticket.priority}';
    }

    // Limit length for tooltip display
    if (description.length > 200) {
      description = '${description.substring(0, 197)}...';
    }

    return description.isNotEmpty ? description : 'No description available';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClaimed =
        ticket.assignedTo != null && ticket.assignedTo!.isNotEmpty;
    final customerAsync = ref.watch(ticketCustomerProvider(ticket.customerId));
    final agentsAsync = ref.watch(agentsListProvider);
    final timeAgo = _formatTime(ticket.createdAt);

    // Resolve assigned agent name
    String? assignedAgentName;
    if (isClaimed) {
      final agents = agentsAsync.value ?? [];
      final agent = agents.firstWhere(
        (a) => a['id']?.toString() == ticket.assignedTo,
        orElse: () => <String, dynamic>{},
      );
      final name =
          agent['full_name']?.toString().trim() ??
          agent['username']?.toString().trim() ??
          '';
      if (name.isNotEmpty) assignedAgentName = name;
    }

    // Determine badge label and color based on status
    final String badgeLabel;
    final Color badgeColor;
    final status = ticket.status;

    if (status == 'BillProcessed' || status == 'BillRaised') {
      badgeLabel = 'Billed';
      badgeColor = const Color(0xFF7C3AED); // purple
    } else if (status == 'Resolved' || status == 'Closed') {
      badgeLabel = 'Resolved';
      badgeColor = AppColors.success;
    } else if (isClaimed) {
      badgeLabel = 'Claimed';
      badgeColor = Colors.grey.shade600;
    } else {
      badgeLabel = 'Unclaimed';
      badgeColor = AppColors.error;
    }

    // Card background/border also reflects status
    final Color cardColor;
    final Color cardBorderColor;
    if (status == 'BillProcessed' || status == 'BillRaised') {
      cardColor = const Color(0xFF7C3AED).withValues(alpha: 0.08);
      cardBorderColor = const Color(0xFF7C3AED).withValues(alpha: 0.3);
    } else if (status == 'Resolved' || status == 'Closed') {
      cardColor = AppColors.success.withValues(alpha: 0.07);
      cardBorderColor = AppColors.success.withValues(alpha: 0.3);
    } else if (isClaimed) {
      cardColor = Colors.white.withValues(alpha: 0.05);
      cardBorderColor = Colors.white.withValues(alpha: 0.1);
    } else {
      cardColor = AppColors.error.withValues(alpha: 0.1);
      cardBorderColor = AppColors.error.withValues(alpha: 0.3);
    }

    return customerAsync.when(
      data: (customerData) {
        final companyName =
            customerData?['company_name']?.toString().trim() ?? '';
        final contactPerson =
            customerData?['contact_person']?.toString().trim() ?? '';

        // Use company name as primary, fallback to contact person
        final customerName = companyName.isNotEmpty
            ? companyName
            : (contactPerson.isNotEmpty ? contactPerson : 'Unknown Customer');
        // ignore: unused_local_variable
        final customerEmail = customerData?['contact_email'] ?? '';

        return Tooltip(
          message: _getTicketDescription(ticket),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.4,
          ),
          waitDuration: const Duration(milliseconds: 500),
          showDuration: const Duration(seconds: 3),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cardBorderColor),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Navigate to ticket detail
                  context.push('/ticket/${ticket.ticketId}');
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer name and claim status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: customer name + time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Right: claimed badge + agent name stacked
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isClaimed && assignedAgentName != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  assignedAgentName,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          'Customer not found',
          style: TextStyle(
            color: Colors.red.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
