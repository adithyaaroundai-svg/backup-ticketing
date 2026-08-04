import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../../../sales/presentation/widgets/create_lead_dialog.dart';
import '../../../sales/presentation/pages/leads_page.dart';
import '../../../sales/presentation/providers/lead_provider.dart';
import '../widgets/sales_team_chat_view.dart';
import '../../../sales/presentation/widgets/lead_search_dialog.dart';
import '../widgets/add_members_page.dart';

class SalesChatPage extends ConsumerStatefulWidget {
  final int initialTab;

  const SalesChatPage({super.key, this.initialTab = 0});

  @override
  ConsumerState<SalesChatPage> createState() => _SalesChatPageState();
}

class _SalesChatPageState extends ConsumerState<SalesChatPage> {
  Future<void> _launchGroupCall({required bool video}) async {
    final agentsAsync = ref.read(agentsListProvider);
    final agents = agentsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <Map<String, dynamic>>[],
    );
    final currentUser = ref.read(authProvider);

    final List<String> teamsIds = [];
    final List<String> zohoIds = [];

    for (final agentData in agents) {
      final memberId = agentData['id']?.toString();
      if (memberId == null || memberId == currentUser?.id) continue;
      final teamsId = agentData['teams_user_id'] as String?;
      if (teamsId != null && teamsId.trim().isNotEmpty) teamsIds.add(teamsId.trim());
      final zohoId = agentData['zoho_cliq_id'] as String?;
      if (zohoId != null && zohoId.trim().isNotEmpty) zohoIds.add(zohoId.trim());
    }

    // Always show both options
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Call Platform'),
        content: const Text('How would you like to call the sales team?'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Microsoft Teams'),
            onPressed: () => Navigator.of(ctx).pop('teams'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Zoho Cliq'),
            onPressed: () => Navigator.of(ctx).pop('zoho'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    if (choice == 'teams') {
      if (teamsIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('None of the sales team members have a Microsoft Teams ID set.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final encoded = Uri.encodeComponent(teamsIds.join(','));
      final url = video
          ? 'https://teams.microsoft.com/l/call/0/0?users=$encoded&withVideo=true'
          : 'https://teams.microsoft.com/l/call/0/0?users=$encoded';
      try {
        await url_launcher.launchUrl(
          Uri.parse(url),
          mode: url_launcher.LaunchMode.externalApplication,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Microsoft Teams. Please make sure it is installed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (zohoIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('None of the sales team members have a Zoho Cliq ID set.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final id = zohoIds.first;
      // Official Zoho Cliq deep link: opens DM with this user (by ZUID or email)
      // https://www.zoho.com/cliq/help/platform/deep-linking.html
      final uri = Uri.parse('https://cliq.zoho.com/users/$id');
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Zoho Cliq. Please make sure it is installed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showMembersDialog(BuildContext context, List<dynamic> agentsList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2124),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Channel Members',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: agentsList.length,
                    itemBuilder: (context, index) {
                      final agent = agentsList[index];
                      final name = agent['full_name']?.toString().isNotEmpty == true 
                                   ? agent['full_name'] 
                                   : agent['username'] ?? 'Unknown';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: agent['email'] != null 
                            ? Text(agent['email'], style: const TextStyle(color: Colors.white70))
                            : null,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChannelDetailsModal(BuildContext parentContext, int memberCount, List<dynamic> actualAgents) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2124),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '#sales-channel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$memberCount members',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white70),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              parentContext,
                              MaterialPageRoute(
                                builder: (_) => AddMembersPage(existingMemberIds: const {
                                  '14db36db-0cb9-44ef-8032-d9610b3bc797',
                                  'b77b3738-4dfc-4515-a1fd-d6fb170423f4',
                                  'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c',
                                  '5a06a8df-97f1-4dbf-bc13-9724a3c779c1',
                                  'd9572a84-762b-4c8b-8ef5-7da0345e3ea8',
                                }),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(LucideIcons.userPlus, size: 18),
                          label: const Text('Add members'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            showDialog(
                              context: parentContext,
                              builder: (_) => const LeadSearchDialog(),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(LucideIcons.search, size: 18),
                          label: const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.chat_bubble, color: Colors.white),
                  title: const Text('Messages', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    DefaultTabController.of(parentContext).animateTo(0);
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.kanban, color: Colors.white),
                  title: const Text('Pipelines', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    DefaultTabController.of(parentContext).animateTo(1);
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.users, color: Colors.white),
                  title: const Text('Members', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showMembersDialog(parentContext, actualAgents);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.toString();
    final tab =
        int.tryParse(
          GoRouterState.of(context).uri.queryParameters['tab'] ?? '0',
        ) ??
        0;

    Widget content;
    switch (tab) {
      case 1:
        content = const _SalesTab();
        break;
      case 2:
        content = const _PipelineTab();
        break;
      default:
        content = const _ChatTab();
    }

    final isMobile = MediaQuery.sizeOf(context).width <= 900;
    
    if (isMobile) {
      final agentsAsync = ref.watch(agentsListProvider);
      
      const allowedSalesChannelIds = {
        '14db36db-0cb9-44ef-8032-d9610b3bc797',
        'b77b3738-4dfc-4515-a1fd-d6fb170423f4',
        'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c',
        '5a06a8df-97f1-4dbf-bc13-9724a3c779c1',
        'd9572a84-762b-4c8b-8ef5-7da0345e3ea8',
        '0a5aeeb8-9544-4dc8-920f-e26c192b0dd3',
        'f3b54de6-0372-4648-ad87-3e98089efc2d',
      };
      
      final agentsList = agentsAsync.asData?.value ?? [];
      final actualAgents = agentsList.where((a) => allowedSalesChannelIds.contains(a['id'])).toList();
      final memberCount = actualAgents.isNotEmpty ? actualAgents.length : allowedSalesChannelIds.length;
      
      return MainLayout(
        currentPath: currentPath,
        child: DefaultTabController(
          length: 2,
          initialIndex: tab,
          child: Builder(
            builder: (tabContext) {
              return Scaffold(
                backgroundColor: context.isDarkMode ? context.adaptiveBackground : AppColors.slate50,
                appBar: AppBar(
                  backgroundColor: context.isDarkMode ? const Color(0xFF1A1D21) : AppColors.primary,
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/mobile-home'),
                  ),
                  titleSpacing: 0,
                  title: GestureDetector(
                    onTap: () => _showChannelDetailsModal(tabContext, memberCount, actualAgents),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              '# ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'sales-channel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                          ],
                        ),
                        Text(
                          '$memberCount members • 2 tabs',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(LucideIcons.plus, size: 24),
                      onPressed: () => showDialog(context: tabContext, builder: (_) => const CreateLeadDialog()),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.search, size: 20),
                      onPressed: () => showDialog(context: tabContext, builder: (_) => const LeadSearchDialog()),
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: const TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(text: 'Sales Chat'),
                      Tab(text: 'Pipelines'),
                    ],
                  ),
                ),
                body: const TabBarView(
                  children: [
                    _ChatTab(),
                    _PipelineTab(),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return MainLayout(
      currentPath: currentPath,
      child: Scaffold(
        backgroundColor: context.isDarkMode ? context.adaptiveBackground : AppColors.slate50,
        body: Stack(
          children: [
            Positioned.fill(child: content),
            // Refresh Button at top left
            Positioned(
              top: 6,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => ref.invalidate(leadsProvider),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.adaptiveBorder),
                    ),
                    child: Icon(
                      LucideIcons.refreshCw,
                      size: 16,
                      color: context.adaptiveSlate500,
                    ),
                  ),
                ),
              ),
            ),
            // Call buttons & Create Lead button at top right
            Positioned(
              top: 6,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (tab != 2) ...[
                    // Audio Call Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _launchGroupCall(video: false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.adaptiveBorder),
                          ),
                          child: Icon(
                            LucideIcons.phone,
                            size: 16,
                            color: context.adaptiveSlate500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Video Call Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _launchGroupCall(video: true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.adaptiveBorder),
                          ),
                          child: Icon(
                            LucideIcons.video,
                            size: 16,
                            color: context.adaptiveSlate500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Create Lead Button (Reduced size)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreateLeadDialog(),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.plus,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Create Lead',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTab extends ConsumerWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SalesTeamChatView();
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Text(
        'Sales - Coming Soon',
        style: TextStyle(fontSize: 16, color: context.adaptiveSlate500),
      ),
    );
  }
}

class _PipelineTab extends ConsumerWidget {
  const _PipelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const LeadsPage(isEmbedded: true);
  }
}
