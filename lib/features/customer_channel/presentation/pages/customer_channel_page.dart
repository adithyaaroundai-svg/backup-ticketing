import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../providers/tally_registrations_provider.dart';

class CustomerChannelPage extends ConsumerWidget {
  const CustomerChannelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationsAsync = ref.watch(tallyRegistrationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.building2, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Customer Channel',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            if (registrationsAsync.hasValue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${registrationsAsync.value!.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh Data',
            onPressed: () {
              ref.invalidate(tallyRegistrationsProvider);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // Content
          Expanded(
            child: registrationsAsync.when(
              data: (registrations) {
                if (registrations.isEmpty) {
                  return Center(
                    child: Text(
                      'No registrations found.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingTextStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  dataTextStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Company Name')),
                                    DataColumn(label: Text('Phone')),
                                    DataColumn(label: Text('Address')),
                                    DataColumn(label: Text('Registered On')),
                                  ],
                                  rows: registrations.map((reg) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(
                                          reg.companyName,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        )),
                                        DataCell(Text(reg.companyPhone ?? '-')),
                                        DataCell(
                                          SizedBox(
                                            width: 300,
                                            child: Tooltip(
                                              message: reg.companyAddress ?? '-',
                                              waitDuration: const Duration(milliseconds: 300),
                                              child: Text(
                                                reg.companyAddress ?? '-',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(
                                          DateFormat('MMM dd, yyyy - hh:mm a').format(reg.createdAt.toLocal()),
                                        )),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading data: ',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
