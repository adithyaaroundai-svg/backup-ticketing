import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';

class NewDmDialog extends ConsumerStatefulWidget {
  const NewDmDialog({super.key});

  @override
  ConsumerState<NewDmDialog> createState() => _NewDmDialogState();
}

class _NewDmDialogState extends ConsumerState<NewDmDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(agentsListProvider);
    final currentUser = ref.watch(authProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Direct Message',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search users...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.search, size: 18),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 16),

              Expanded(
                child: agentsAsync.when(
                  data: (agents) {
                    final hiddenAgentIds = const {
                      '2d58eb0a-916a-4cb6-9245-b5b124caa0a3',
                    };
                    
                    final filteredAgents = agents.where((a) {
                      final id = a['id'] as String;
                      if (hiddenAgentIds.contains(id)) return false;
                      
                      final name = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
                      
                      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
                        return false;
                      }
                      
                      return true;
                    }).toList();

                    if (filteredAgents.isEmpty) return const Center(child: Text('No users found.'));

                    return ListView.builder(
                      itemCount: filteredAgents.length,
                      itemBuilder: (context, index) {
                        final a = filteredAgents[index];
                        final id = a['id'] as String;
                        final name = a['full_name'] ?? a['username'] ?? 'Unknown';
                        
                        final isCurrentUser = currentUser?.id == id;
                        final displayName = isCurrentUser ? '$name (You)' : name;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary,
                            backgroundImage: a['avatar_url'] != null ? NetworkImage(a['avatar_url']) : null,
                            child: a['avatar_url'] == null 
                                ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14))
                                : null,
                          ),
                          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(a['role'] ?? ''),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go('/chat/dm/$id');
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
