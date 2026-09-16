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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.building2, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Customer Channel',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (registrationsAsync.hasValue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: isDark ? Border.all(color: primaryColor.withOpacity(0.3), width: 1) : null,
                ),
                child: Text(
                  '${registrationsAsync.value!.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            tooltip: 'Refresh Data',
            onPressed: () {
              ref.invalidate(tallyRegistrationsProvider);
            },
          ),
          const SizedBox(width: 8),
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
