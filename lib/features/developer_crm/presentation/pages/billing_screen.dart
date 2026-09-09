import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/money_utils.dart';
import '../../core/time_utils.dart';
import '../providers/billing_provider.dart';
import '../widgets/common.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<BillingProvider>();
        if (prov.data == null && !prov.loading) {
          prov.load();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _BillingBody();
  }
}

class _BillingBody extends StatefulWidget {
  const _BillingBody();

  @override
  State<_BillingBody> createState() => _BillingBodyState();
}

class _BillingBodyState extends State<_BillingBody> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BillingProvider>();
    if (prov.loading && prov.data == null) return const CenterLoading();
    if (prov.error != null && prov.data == null) {
      return ErrorBanner(message: prov.error!, onRetry: prov.load);
    }
    final data = prov.data!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: math.max(constraints.maxWidth, 1000), // Enforce minimum width
              ),
              child: RefreshIndicator(
                onRefresh: prov.load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Billing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (data.readOnly) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Text('Read-only view for accountants.'),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Grand billed', value: data.grandBilled),
                  _Stat(label: 'Grand advances', value: data.grandAdvances),
                  _Stat(label: 'Grand balance', value: data.grandBalance),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final g in data.groups)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(g.client, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          'Billed ${fmtMoney(g.billed)} \u2022 Advances ${fmtMoney(g.advances)} \u2022 Balance ${fmtMoney(g.balance)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DataTable(
                      columns: const [
                          DataColumn(label: Text('Task')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Bill amount')),
                          DataColumn(label: Text('Advances')),
                          DataColumn(label: Text('Balance')),
                          DataColumn(label: Text('Completed')),
                        ],
                        rows: [
                          for (final t in g.tasks)
                            DataRow(
                              onSelectChanged: (_) => context.push('/tasks/${t.id}'),
                              cells: [
                                DataCell(ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 220),
                                  child: Text(t.description, overflow: TextOverflow.ellipsis, maxLines: 2),
                                )),
                                DataCell(StatusChip(status: t.status)),
                                DataCell(Text(fmtMoney(t.billAmount))),
                                DataCell(Text(fmtMoney(t.advancesTotal))),
                                DataCell(Text(fmtMoney(t.balance))),
                                DataCell(Text(t.completedAt == null ? '-' : fmtDateTimeIst(t.completedAt))),
                              ],
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (data.groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No billed tasks yet.', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    ),
  ),
),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final num value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(fmtMoney(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
