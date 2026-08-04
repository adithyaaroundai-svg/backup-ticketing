import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../providers/lead_provider.dart';
import 'edit_lead_dialog.dart';

class LeadSearchDialog extends ConsumerStatefulWidget {
  const LeadSearchDialog({super.key});

  @override
  ConsumerState<LeadSearchDialog> createState() => _LeadSearchDialogState();
}

class _LeadSearchDialogState extends ConsumerState<LeadSearchDialog> {
  String _searchQuery = '';
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsStreamProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E2124) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search leads by name, customer, product...',
                hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.white54 : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black26),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: leadsAsync.when(
                data: (leads) {
                  final filtered = leads.where((l) {
                    if (_searchQuery.isEmpty) return true;
                    final name = (l.customerName ?? '').toLowerCase();
                    final company = (l.companyName).toLowerCase();
                    final product = (l.product ?? '').toLowerCase();
                    return name.contains(_searchQuery) || 
                           company.contains(_searchQuery) || 
                           product.contains(_searchQuery);
                  }).toList();
                  
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No leads found',
                        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
                      )
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final lead = filtered[index];
                      return ListTile(
                        title: Text(
                          lead.customerName ?? lead.companyName,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          '${lead.companyName} • ${lead.product ?? 'N/A'}',
                          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: lead.status.toLowerCase() == 'won' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lead.status,
                            style: TextStyle(
                              fontSize: 12,
                              color: lead.status.toLowerCase() == 'won' ? Colors.green : Colors.orange
                            ),
                          ),
                        ),
                        onTap: () {
                           Navigator.pop(context);
                           showDialog(
                             context: context,
                             builder: (_) => EditLeadDialog(lead: lead),
                           );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error loading leads: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
