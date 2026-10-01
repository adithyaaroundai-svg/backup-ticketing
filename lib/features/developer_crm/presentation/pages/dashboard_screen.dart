import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/theme/app_theme.dart';
import '../../core/money_utils.dart';
import '../../core/time_utils.dart';
import '../../domain/entities/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/board_chrome.dart';
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

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

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

    return RefreshIndicator(
      onRefresh: prov.load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BoardPageHeader(
                    title: 'Dashboard',
                    subtitle: 'Week of ${fmtDate(data.weekStart)}',
                  ),
                ),
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
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Back up now'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _StatCard(
                    label: 'Active tasks',
                    value: '${data.cards.activeTasks}',
                    icon: Icons.bolt_rounded,
                    color: AppColors.primary,
                  ),
                  _StatCard(
                    label: 'Overdue',
                    value: '${data.cards.overdue}',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.error,
                    tinted: data.cards.overdue > 0,
                  ),
                  _StatCard(
                    label: 'Working now',
                    value: '${data.cards.workingNow}',
                    icon: Icons.play_circle_outline_rounded,
                    color: AppColors.accent,
                  ),
                  _StatCard(
                    label: 'Completed this week',
                    value: '${data.cards.completedWeek}',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                  ),
                ];
                if (constraints.maxWidth < 800) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [for (final card in cards) SizedBox(width: 220, child: card)],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final money = [
                  _MoneyCard(label: 'Billed', value: data.money.billed, icon: Icons.receipt_long_outlined, color: AppColors.primary),
                  _MoneyCard(label: 'Advances', value: data.money.advances, icon: Icons.payments_outlined, color: AppColors.accent),
                  _MoneyCard(
                    label: 'Balance',
                    value: data.money.balance,
                    icon: Icons.account_balance_wallet_outlined,
                    color: data.money.balance < 0 ? AppColors.error : AppColors.success,
                  ),
                ];
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (var i = 0; i < money.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        money[i],
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < money.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: money[i]),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Client profitability'),
            const SizedBox(height: 8),
            _FillTable(
              headers: const ['Client', 'Billed', 'Advances', 'Balance', 'Hours', 'Rate/hr'],
              flexes: const [4, 2, 2, 2, 2, 2],
              alignEnd: const [false, true, true, true, true, true],
              emptyMessage: 'No billed or active clients yet.',
              rows: [
                for (final client in data.clients)
                  [
                    client.name,
                    fmtMoney(client.billed),
                    fmtMoney(client.advances),
                    fmtMoney(client.balance),
                    client.hours.toStringAsFixed(2),
                    client.rate == null ? '-' : fmtMoney(client.rate),
                  ],
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Team this week'),
            const SizedBox(height: 8),
            _FillTable(
              headers: const ['Name', 'Role', 'Active', 'Completed', 'Working now', 'Time logged'],
              flexes: const [3, 2, 2, 2, 2, 2],
              alignEnd: const [false, false, true, true, true, true],
              emptyMessage: 'No team activity this week.',
              rows: [
                for (final person in data.developers)
                  [
                    person.name,
                    person.role.replaceAll('_', ' '),
                    '${person.active}',
                    '${person.completedWeek}',
                    '${person.workingNow}',
                    fmtDuration(person.seconds),
                  ],
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Backups'),
            const SizedBox(height: 8),
            _BackupCard(data: data),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.tinted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tinted ? color.withValues(alpha: 0.35) : AppColors.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: tinted ? color : AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final num value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  fmtMoney(value),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slate900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FillTable extends StatelessWidget {
  const _FillTable({
    required this.headers,
    required this.flexes,
    required this.alignEnd,
    required this.rows,
    required this.emptyMessage,
  });

  final List<String> headers;
  final List<int> flexes;
  final List<bool> alignEnd;
  final List<List<String>> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return BoardTableCard(
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Center(
                child: Text(emptyMessage, style: const TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w500)),
              ),
            )
          : Column(
              children: [
                _band(
                  color: AppColors.slate100,
                  border: const Border(bottom: BorderSide(color: AppColors.border)),
                  values: headers,
                  bold: true,
                  colorText: AppColors.slate600,
                ),
                for (var i = 0; i < rows.length; i++)
                  _band(
                    color: i.isOdd ? AppColors.slate50 : Colors.white,
                    border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
                    values: rows[i],
                    bold: false,
                    colorText: AppColors.slate800,
                  ),
              ],
            ),
    );
  }

  Widget _band({
    required Color color,
    required Border border,
    required List<String> values,
    required bool bold,
    required Color colorText,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(color: color, border: border),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              flex: flexes[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  values[i],
                  textAlign: alignEnd[i] ? TextAlign.right : TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: colorText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final backup = data.lastBackup;
    final ok = backup?.status == 'ok';
    final color = backup == null ? AppColors.slate500 : (ok ? AppColors.success : AppColors.error);
    final title = backup == null ? 'No backups recorded yet' : (backup.objectKey ?? 'Backup');
    final detail = backup == null
        ? 'A backup has not been stored for this workspace.'
        : '${fmtDateTimeIst(backup.createdAt)}'
            '${backup.sizeBytes != null ? '  ·  ${(backup.sizeBytes! / 1024).toStringAsFixed(1)} KB' : ''}'
            '  ·  ${backup.status ?? ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(backup == null ? Icons.cloud_off_outlined : (ok ? Icons.cloud_done_outlined : Icons.error_outline), color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
