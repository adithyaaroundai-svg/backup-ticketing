import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../providers/chat_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';

class AddMembersPage extends ConsumerStatefulWidget {
  final Set<String> existingMemberIds;
  
  const AddMembersPage({
    super.key,
    required this.existingMemberIds,
  });

  @override
  ConsumerState<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends ConsumerState<AddMembersPage> {
  String _searchQuery = '';
  final Set<String> _selectedAgentIds = {};

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2124) : AppColors.slate50;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    final agentsAsync = ref.watch(agentsListProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Add people', style: TextStyle(color: textColor, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _selectedAgentIds.isEmpty
                ? null
                : () {
                    // Logic to add members
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Members added (UI only)')),
                    );
                    Navigator.pop(context);
                  },
            child: Text(
              'Add',
              style: TextStyle(
                color: _selectedAgentIds.isEmpty ? Colors.grey : AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'ex. Nathalie, or james@acme.com',
                hintStyle: TextStyle(color: subTextColor),
                prefixIcon: Icon(Icons.search, color: subTextColor),
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 1),
          // Agents List
          Expanded(
            child: agentsAsync.when(
              data: (agents) {
                // Filter out those who are already in the channel
                final nonMembers = agents.where((a) => !widget.existingMemberIds.contains(a['id'])).toList();
                
                final filtered = nonMembers.where((a) {
                  if (_searchQuery.isEmpty) return true;
                  final name = (a['full_name'] ?? '').toString().toLowerCase();
                  final email = (a['email'] ?? '').toString().toLowerCase();
                  final username = (a['username'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery) || username.contains(_searchQuery);
                }).toList();

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => Divider(
                    color: isDarkMode ? Colors.white12 : Colors.black12,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final agent = filtered[index];
                    final id = agent['id'] as String;
                    final isSelected = _selectedAgentIds.contains(id);
                    
                    final name = agent['full_name']?.toString().isNotEmpty == true 
                                 ? agent['full_name'] 
                                 : agent['username'] ?? 'Unknown';
                    final subtitle = agent['email'] ?? agent['username'] ?? '';

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            backgroundImage: agent['avatar_url'] != null ? NetworkImage(agent['avatar_url']) : null,
                            child: agent['avatar_url'] == null 
                                ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: bgColor, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: RichText(
                        text: TextSpan(
                          text: name,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
                          children: [
                            TextSpan(
                              text: subtitle.isNotEmpty ? ' $subtitle' : '',
                              style: TextStyle(color: subTextColor, fontWeight: FontWeight.normal, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedAgentIds.add(id);
                            } else {
                              _selectedAgentIds.remove(id);
                            }
                          });
                        },
                        side: BorderSide(color: subTextColor),
                        activeColor: AppColors.primary,
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedAgentIds.remove(id);
                          } else {
                            _selectedAgentIds.add(id);
                          }
                        });
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
