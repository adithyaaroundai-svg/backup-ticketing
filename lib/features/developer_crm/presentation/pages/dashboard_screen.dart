import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money_utils.dart';
import '../../core/time_utils.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<DashboardProvider>();
        if (prov.data == null && !prov.loading) {
          prov.load();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _DashboardBody();
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    if (prov.data == null) {
      if (prov.error != null) {
        return ErrorBanner(message: prov.error!, onRetry: () => prov.load());
      }
      return const CenterLoading();
    }
    final data = prov.data!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double contentWidth = math.max(constraints.maxWidth, 1000.0) - 32;
        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: math.max(constraints.maxWidth, 1000.0), // Enforce minimum width
              ),
              child: RefreshIndicator(
                onRefresh: prov.load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: contentWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Dashboard \u2014 week of ${fmtDate(data.weekStart)}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            FilledButton.icon(
                              onPressed: prov.backingUp
                                  ? null
                                  : () async {
                                      await prov.backupNow();
                                      if (context.mounted) {
                                        showSavedSnack(context, ok: true, message: 'Backup triggered');
                                      }
                                    },
                              icon: prov.backingUp
                                  ? const SizedBox(
                                      height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.backup),
                              label: const Text('Back up now'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: contentWidth,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _HeadlineCard(label: 'Active tasks', value: '${data.cards.activeTasks}'),
                            _HeadlineCard(label: 'Overdue', value: '${data.cards.overdue}', warn: true),
                            _HeadlineCard(label: 'Working now', value: '${data.cards.workingNow}'),
                            _HeadlineCard(label: 'Completed this week', value: '${data.cards.completedWeek}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: contentWidth,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MoneyStat(label: 'Billed', value: data.money.billed),
                                _MoneyStat(label: 'Advances', value: data.money.advances),
                                _MoneyStat(label: 'Balance', value: data.money.balance),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Client profitability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        child: DataTable(
                          columns: const [
                              DataColumn(label: Text('Client')),
                              DataColumn(label: Text('Billed')),
                              DataColumn(label: Text('Advances')),
                              DataColumn(label: Text('Balance')),
                              DataColumn(label: Text('Hours')),
                              DataColumn(label: Text('Rate/hr')),
                            ],
                            rows: [
                              for (final c in data.clients)
                                DataRow(cells: [
                                  DataCell(Text(c.name)),
                                  DataCell(Text(fmtMoney(c.billed))),
                                  DataCell(Text(fmtMoney(c.advances))),
                                  DataCell(Text(fmtMoney(c.balance))),
                                  DataCell(Text(c.hours.toStringAsFixed(2))),
                                  DataCell(Text(c.rate == null ? '-' : fmtMoney(c.rate))),
                                ]),
                              if (data.clients.isEmpty)
                                const DataRow(cells: [
                                  DataCell(Text('No billed/active clients yet')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text('Team this week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        child: DataTable(
                          columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Active')),
                              DataColumn(label: Text('Completed this week')),
                              DataColumn(label: Text('Working now')),
                              DataColumn(label: Text('Time logged')),
                            ],
                            rows: [
                              for (final d in data.developers)
                                DataRow(cells: [
                                  DataCell(Text(d.name)),
                                  DataCell(Text(d.role.replaceAll('_', ' '))),
                                  DataCell(Text('${d.active}')),
                                  DataCell(Text('${d.completedWeek}')),
                                  DataCell(Text('${d.workingNow}')),
                                  DataCell(Text(fmtDuration(d.seconds))),
                                ]),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text('Backups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: contentWidth,
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              data.lastBackup?.status == 'ok' ? Icons.check_circle : Icons.error,
                              color: data.lastBackup?.status == 'ok' ? Colors.green : Colors.red,
                            ),
                            title: Text(data.lastBackup == null
                                ? 'No backups recorded yet'
                                : (data.lastBackup!.objectKey ?? 'backup')),
                            subtitle: data.lastBackup == null
                                ? null
                                : Text(
                                    '${fmtDateTimeIst(data.lastBackup!.createdAt)}'
                                    '${data.lastBackup!.sizeBytes != null ? ' \u2022 ${(data.lastBackup!.sizeBytes! / 1024).toStringAsFixed(1)} KB' : ''}'
                                    ' \u2022 ${data.lastBackup!.status ?? ''}'),
                          ),
                        ),
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

class _HeadlineCard extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _HeadlineCard({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        color: warn ? Colors.red.withValues(alpha: 0.08) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  final String label;
  final num value;
  const _MoneyStat({required this.label, required this.value});

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
