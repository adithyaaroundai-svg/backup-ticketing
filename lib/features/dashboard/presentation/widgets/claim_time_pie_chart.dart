import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Who is allowed to see the live ticket metric charts.
class ClaimTimeAudience {
  static const saneeshaId = '26a252ac-1ace-46e8-aa86-1ce7d52fe578';
  static const anilKumarId = '14db36db-0cb9-44ef-8032-d9610b3bc797';
  static const sidharthId = 'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c';

  static bool showOnSupport(Agent? user) => _isSaneesha(user);

  static bool showOnAdmin(Agent? user) => _isAnilKumar(user) || _isSidharth(user);

  static String _key(Agent user) {
    return '${user.fullName} ${user.username}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _isSaneesha(Agent? user) {
    if (user == null) return false;
    if (user.id == saneeshaId) return true;
    return _key(user).contains('saneesha');
  }

  static bool _isAnilKumar(Agent? user) {
    if (user == null) return false;
    if (user.id == anilKumarId) return true;
    final key = _key(user);
    final full = user.fullName.trim().toLowerCase();
    final username = user.username.trim().toLowerCase();
    return key.contains('anilkumar') ||
        full == 'anil' ||
        username == 'anil' ||
        username == 'anilkumar';
  }

  static bool _isSidharth(Agent? user) {
    if (user == null) return false;
    if (user.id == sidharthId) return true;
    final full = user.fullName.trim().toLowerCase();
    final username = user.username.trim().toLowerCase();
    return full.contains('sidharth') || username.contains('sidharth');
  }
}

const _resolvedStatuses = {
  'resolved',
  'closed',
  'billprocessed',
  'billraised',
};

class _TicketSnap {
  final String id;
  final int? number;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime? firstClaimedAt;
  final DateTime? resolvedAt;

  const _TicketSnap({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.firstClaimedAt,
    required this.resolvedAt,
  });

  bool get cancelled {
    final value = status.trim().toLowerCase();
    return value == 'cancelled' || value == 'canceled';
  }

  bool get isResolved => _resolvedStatuses.contains(status.trim().toLowerCase());

  String get label {
    if (number != null) return '#$number';
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  static _TicketSnap? fromRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final createdAt = _parseDate(row['created_at']);
    if (id == null || id.isEmpty || createdAt == null) return null;
    final status = (row['status'] ?? 'New').toString();
    final normalized = status.trim().toLowerCase();
    DateTime? resolvedAt;
    if (_resolvedStatuses.contains(normalized)) {
      resolvedAt = _parseDate(row['completed_at']) ?? _parseDate(row['updated_at']);
    }
    return _TicketSnap(
      id: id,
      number: (row['ticket_number'] as num?)?.toInt(),
      title: (row['title'] ?? '').toString(),
      status: status,
      createdAt: createdAt,
      firstClaimedAt: _firstClaimedAt(row['assignment_history']),
      resolvedAt: resolvedAt,
    );
  }
}

class _SliceTicket {
  final _TicketSnap ticket;
  final String detail;

  const _SliceTicket({required this.ticket, required this.detail});
}

class _Slice {
  final String label;
  final Color color;
  final List<_SliceTicket> tickets;
  final List<_Slice> breakdown;

  const _Slice({
    required this.label,
    required this.color,
    required this.tickets,
    this.breakdown = const [],
  });

  int get count => tickets.length;
}

class _ChartModel {
  final String title;
  final String subtitle;
  final String centerValue;
  final String centerCaption;
  final String footer;
  final List<_Slice> slices;

  const _ChartModel({
    required this.title,
    required this.subtitle,
    required this.centerValue,
    required this.centerCaption,
    required this.footer,
    required this.slices,
  });

  int get total => slices.fold(0, (sum, slice) => sum + slice.count);
}

final allStatusTicketsProvider = StreamProvider<List<_TicketSnap>>((ref) async* {
  while (true) {
    try {
      yield await _fetchAllStatuses();
    } catch (_) {}
    await Future<void>.delayed(const Duration(seconds: 45));
  }
});

Future<List<_TicketSnap>> _fetchAllStatuses() async {
  final supabase = Supabase.instance.client;
  final all = <_TicketSnap>[];
  const pageSize = 1000;
  var from = 0;
  while (true) {
    final rows = await supabase
        .from('tickets')
        .select('id, ticket_number, title, status, created_at')
        .order('created_at', ascending: false)
        .range(from, from + pageSize - 1);
    final page = List<Map<String, dynamic>>.from(rows as List);
    for (final row in page) {
      final ticket = _TicketSnap.fromRow(row);
      if (ticket != null) all.add(ticket);
    }
    if (page.length < pageSize || from >= 20000) break;
    from += pageSize;
  }
  return all;
}

final claimTimeTicketsProvider = StreamProvider<List<_TicketSnap>>((ref) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(2000)
      .map((rows) {
        return rows
            .map((row) => _TicketSnap.fromRow(Map<String, dynamic>.from(row)))
            .whereType<_TicketSnap>()
            .toList();
      });
});

class ClaimTimePieChart extends ConsumerStatefulWidget {
  const ClaimTimePieChart({super.key});

  @override
  ConsumerState<ClaimTimePieChart> createState() => _ClaimTimePieChartState();
}

class _ClaimTimePieChartState extends ConsumerState<ClaimTimePieChart>
    with SingleTickerProviderStateMixin {
  Timer? _tick;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _openSlice(_Slice slice) {
    final tickets = [...slice.tickets]
      ..sort((a, b) => b.ticket.createdAt.compareTo(a.ticket.createdAt));
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final titleColor = Theme.of(dialogContext).brightness == Brightness.dark
                ? Colors.white
                : AppColors.slate900;
            final muted = Theme.of(dialogContext).brightness == Brightness.dark
                ? Colors.white70
                : AppColors.slate500;
            final filtered = query.trim().isEmpty
                ? tickets
                : tickets.where((item) {
                    final haystack =
                        '${item.ticket.label} ${item.ticket.title} ${item.ticket.status}'
                            .toLowerCase();
                    return haystack.contains(query.trim().toLowerCase());
                  }).toList();
            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: slice.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${slice.label} · ${filtered.length}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (tickets.length > 8)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Search ticket number or title',
                            prefixIcon: Icon(Icons.search, size: 18),
                          ),
                          onChanged: (value) => setDialogState(() => query = value),
                        ),
                      ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            title: Text(
                              '${item.ticket.label}  ${item.ticket.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                            ),
                            subtitle: Text(
                              '${item.ticket.status} · ${item.detail}',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              this.context.push('/ticket/${item.ticket.id}');
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(claimTimeTicketsProvider);
    final statusAsync = ref.watch(allStatusTicketsProvider);
    final now = DateTime.now();

    return ticketsAsync.when(
      data: (tickets) {
        final statusTickets = statusAsync.asData?.value ?? tickets;
        final charts = [
          _claimChart(tickets, now),
          _resolveChart(tickets, now),
          _statusChart(statusTickets, complete: statusAsync.hasValue),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            final cards = [
              for (final chart in charts)
                _PieCard(
                  model: chart,
                  pulse: _pulse,
                  showLive: chart.title == 'Time to claim',
                  onSlice: _openSlice,
                ),
            ];
            if (stacked) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    cards[i],
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        );
      },
      loading: () => const AppCard(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => const AppCard(
        child: SizedBox(
          height: 120,
          child: Center(child: Text('Could not load ticket metrics')),
        ),
      ),
    );
  }
}

class _PieCard extends StatefulWidget {
  final _ChartModel model;
  final Animation<double> pulse;
  final bool showLive;
  final ValueChanged<_Slice> onSlice;

  const _PieCard({
    required this.model,
    required this.pulse,
    required this.showLive,
    required this.onSlice,
  });

  @override
  State<_PieCard> createState() => _PieCardState();
}

class _PieCardState extends State<_PieCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.slate900;
    final muted = isDark ? Colors.white70 : AppColors.slate500;
    final model = widget.model;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.subtitle,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              if (widget.showLive)
                FadeTransition(
                  opacity: Tween<double>(begin: 0.35, end: 1).animate(widget.pulse),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (model.total == 0)
            SizedBox(
              height: 140,
              child: Center(
                child: Text('No tickets in this view', style: TextStyle(color: muted)),
              ),
            )
          else
            _ChartBody(
              model: model,
              touchedIndex: _touchedIndex,
              muted: muted,
              titleColor: titleColor,
              onHover: (index) {
                if (_touchedIndex == index) return;
                setState(() => _touchedIndex = index);
              },
              onSlice: widget.onSlice,
            ),
        ],
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  final _ChartModel model;
  final int touchedIndex;
  final Color muted;
  final Color titleColor;
  final ValueChanged<int> onHover;
  final ValueChanged<_Slice> onSlice;

  const _ChartBody({
    required this.model,
    required this.touchedIndex,
    required this.muted,
    required this.titleColor,
    required this.onHover,
    required this.onSlice,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 420;
        final chart = SizedBox(
          height: 168,
          width: stacked ? double.infinity : 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final section = response?.touchedSection;
                      if (!event.isInterestedForInteractions || section == null) {
                        onHover(-1);
                        return;
                      }
                      final index = section.touchedSectionIndex;
                      onHover(index);
                      if (event is FlTapUpEvent &&
                          index >= 0 &&
                          index < model.slices.length) {
                        final slice = model.slices[index];
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onSlice(slice);
                        });
                      }
                    },
                  ),
                  sections: [
                    for (var i = 0; i < model.slices.length; i++)
                      PieChartSectionData(
                        value: model.slices[i].count.toDouble(),
                        color: model.slices[i].color,
                        radius: touchedIndex == i ? 56 : 46,
                        title: _slicePercentLabel(model, i),
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
              ),
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.centerValue,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      model.centerCaption,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final legend = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final slice in model.slices) ...[
              _LegendRow(
                slice: slice,
                total: model.total,
                muted: muted,
                onTap: () => onSlice(slice),
              ),
              for (final child in slice.breakdown)
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: _LegendRow(
                    slice: child,
                    total: model.total,
                    muted: muted,
                    onTap: () => onSlice(child),
                  ),
                ),
              const SizedBox(height: 6),
            ],
            Text(model.footer, style: TextStyle(fontSize: 12, color: muted)),
          ],
        );

        if (stacked) {
          return Column(
            children: [
              chart,
              const SizedBox(height: 8),
              legend,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 12),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LegendRow extends StatelessWidget {
  final _Slice slice;
  final int total;
  final Color muted;
  final VoidCallback onTap;

  const _LegendRow({
    required this.slice,
    required this.total,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : ((slice.count / total) * 100).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: slice.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                slice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Text(
              '${slice.count} · $percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_ChartModel _claimChart(List<_TicketSnap> tickets, DateTime now) {
  final today = _todayTickets(tickets, now);
  final buckets = <String, List<_SliceTicket>>{
    'fast': [],
    'normal': [],
    'slow': [],
    'waitingFresh': [],
    'waitingLate': [],
  };
  var claimed = 0;
  var waitSum = Duration.zero;

  for (final ticket in today) {
    if (ticket.cancelled) continue;
    final claimedAt = ticket.firstClaimedAt;
    if (claimedAt == null) {
      final age = now.difference(ticket.createdAt);
      final target = age >= const Duration(hours: 1) ? 'waitingLate' : 'waitingFresh';
      buckets[target]!.add(
        _SliceTicket(ticket: ticket, detail: 'Waiting ${_formatDuration(age)}'),
      );
      continue;
    }
    var wait = claimedAt.difference(ticket.createdAt);
    if (wait.isNegative) wait = Duration.zero;
    claimed++;
    waitSum += wait;
    final key = wait < const Duration(minutes: 15)
        ? 'fast'
        : wait < const Duration(hours: 1)
            ? 'normal'
            : 'slow';
    buckets[key]!.add(
      _SliceTicket(ticket: ticket, detail: 'Claimed in ${_formatDuration(wait)}'),
    );
  }

  final slices = <_Slice>[
    if (buckets['fast']!.isNotEmpty)
      _Slice(label: 'Claimed < 15m', color: AppColors.success, tickets: buckets['fast']!),
    if (buckets['normal']!.isNotEmpty)
      _Slice(
        label: 'Claimed 15m–1h',
        color: AppColors.primaryLight,
        tickets: buckets['normal']!,
      ),
    if (buckets['slow']!.isNotEmpty)
      _Slice(
        label: 'Claimed > 1h',
        color: const Color(0xFFEA580C),
        tickets: buckets['slow']!,
      ),
    if (buckets['waitingFresh']!.isNotEmpty)
      _Slice(
        label: 'Waiting < 1h',
        color: AppColors.warning,
        tickets: buckets['waitingFresh']!,
      ),
    if (buckets['waitingLate']!.isNotEmpty)
      _Slice(
        label: 'Waiting > 1h',
        color: AppColors.error,
        tickets: buckets['waitingLate']!,
      ),
  ];
  final waiting = buckets['waitingFresh']!.length + buckets['waitingLate']!.length;

  return _ChartModel(
    title: 'Time to claim',
    subtitle: "Today's wait before the first claim",
    centerValue: claimed == 0 ? '—' : _formatDuration(waitSum ~/ claimed),
    centerCaption: 'avg claim',
    footer: '$claimed claimed · $waiting waiting',
    slices: slices,
  );
}

_ChartModel _resolveChart(List<_TicketSnap> tickets, DateTime now) {
  final today = _todayTickets(tickets, now);
  final buckets = <String, List<_SliceTicket>>{
    'fast': [],
    'normal': [],
    'slow': [],
    'openFresh': [],
    'openLate': [],
  };
  var resolved = 0;
  var sum = Duration.zero;

  for (final ticket in today) {
    if (ticket.cancelled) continue;
    final resolvedAt = ticket.resolvedAt;
    if (resolvedAt == null) {
      final age = now.difference(ticket.createdAt);
      final target = age >= const Duration(hours: 4) ? 'openLate' : 'openFresh';
      buckets[target]!.add(
        _SliceTicket(ticket: ticket, detail: 'Open ${_formatDuration(age)}'),
      );
      continue;
    }
    var duration = resolvedAt.difference(ticket.createdAt);
    if (duration.isNegative) duration = Duration.zero;
    resolved++;
    sum += duration;
    final key = duration < const Duration(hours: 1)
        ? 'fast'
        : duration < const Duration(hours: 4)
            ? 'normal'
            : 'slow';
    buckets[key]!.add(
      _SliceTicket(ticket: ticket, detail: 'Resolved in ${_formatDuration(duration)}'),
    );
  }

  final slices = <_Slice>[
    if (buckets['fast']!.isNotEmpty)
      _Slice(label: 'Resolved < 1h', color: AppColors.success, tickets: buckets['fast']!),
    if (buckets['normal']!.isNotEmpty)
      _Slice(
        label: 'Resolved 1–4h',
        color: AppColors.info,
        tickets: buckets['normal']!,
      ),
    if (buckets['slow']!.isNotEmpty)
      _Slice(
        label: 'Resolved > 4h',
        color: const Color(0xFFEA580C),
        tickets: buckets['slow']!,
      ),
    if (buckets['openFresh']!.isNotEmpty)
      _Slice(
        label: 'Open < 4h',
        color: AppColors.warning,
        tickets: buckets['openFresh']!,
      ),
    if (buckets['openLate']!.isNotEmpty)
      _Slice(label: 'Open > 4h', color: AppColors.error, tickets: buckets['openLate']!),
  ];
  final open = buckets['openFresh']!.length + buckets['openLate']!.length;

  return _ChartModel(
    title: 'Time to resolve',
    subtitle: 'Today, from created to resolved',
    centerValue: resolved == 0 ? '—' : _formatDuration(sum ~/ resolved),
    centerCaption: 'avg resolve',
    footer: '$resolved resolved · $open still open',
    slices: slices,
  );
}

_ChartModel _statusChart(List<_TicketSnap> tickets, {required bool complete}) {
  const groupOrder = ['Resolved', 'Closed', 'New', 'In progress', 'Billing', 'Other'];
  final groups = {for (final name in groupOrder) name: <_SliceTicket>[]};
  final otherByStatus = <String, List<_SliceTicket>>{};
  final otherLabels = <String, String>{};

  for (final ticket in tickets) {
    final key = ticket.status.trim().toLowerCase();
    final label = ticket.status.trim().isEmpty ? 'Unknown' : ticket.status.trim();
    final item = _SliceTicket(
      ticket: ticket,
      detail: 'Created ${_formatDay(ticket.createdAt.toLocal())}',
    );
    final group = _statusGroup(key);
    groups[group]!.add(item);
    if (group == 'Other') {
      otherLabels.putIfAbsent(key, () => label);
      otherByStatus.putIfAbsent(key, () => []).add(item);
    }
  }

  final total = tickets.length;
  if (groups['Billing']!.isNotEmpty &&
      (total == 0 || groups['Billing']!.length / total < 0.03)) {
    for (final item in groups['Billing']!) {
      final key = item.ticket.status.trim().toLowerCase();
      final label = item.ticket.status.trim().isEmpty ? 'Billing' : item.ticket.status.trim();
      otherLabels.putIfAbsent(key, () => label);
      otherByStatus.putIfAbsent(key, () => []).add(item);
    }
    groups['Billing'] = [];
  }

  final otherKeys = otherByStatus.keys.toList()
    ..sort((a, b) => otherByStatus[b]!.length.compareTo(otherByStatus[a]!.length));

  final slices = <_Slice>[
    for (final name in groupOrder)
      if (groups[name]!.isNotEmpty)
        _Slice(
          label: name,
          color: _groupColor(name),
          tickets: groups[name]!,
          breakdown: name == 'Other'
              ? [
                  for (final key in otherKeys)
                    _Slice(
                      label: otherLabels[key]!,
                      color: _statusColor(key),
                      tickets: otherByStatus[key]!,
                    ),
                ]
              : const [],
        ),
  ];

  return _ChartModel(
    title: 'All-time status',
    subtitle: complete ? 'Every ticket, by current status' : 'Loading the full ticket history',
    centerValue: '$total',
    centerCaption: 'tickets',
    footer: 'Tap a slice or a status to open those tickets',
    slices: slices,
  );
}

String _statusGroup(String status) {
  switch (status) {
    case 'resolved':
      return 'Resolved';
    case 'closed':
      return 'Closed';
    case 'new':
    case 'open':
      return 'New';
    case 'in progress':
    case 'inprogress':
      return 'In progress';
    case 'billraised':
    case 'billprocessed':
      return 'Billing';
    default:
      return 'Other';
  }
}

Color _groupColor(String group) {
  switch (group) {
    case 'Resolved':
      return AppColors.statusResolved;
    case 'Closed':
      return AppColors.statusClosed;
    case 'New':
      return AppColors.statusNew;
    case 'In progress':
      return AppColors.statusInProgress;
    case 'Billing':
      return const Color(0xFFDB2777);
    default:
      return const Color(0xFF7C3AED);
  }
}

String _slicePercentLabel(_ChartModel model, int index) {
  if (model.total == 0) return '';
  final share = model.slices[index].count / model.total;
  if (share < 0.08) return '';
  return '${(share * 100).round()}%';
}

List<_TicketSnap> _todayTickets(List<_TicketSnap> tickets, DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  return tickets.where((ticket) {
    final created = ticket.createdAt.toLocal();
    return !created.isBefore(start) && created.isBefore(end);
  }).toList();
}

Color _statusColor(String status) {
  switch (status) {
    case 'new':
      return AppColors.statusNew;
    case 'open':
      return AppColors.statusOpen;
    case 'in progress':
    case 'inprogress':
      return AppColors.statusInProgress;
    case 'waiting for customer':
    case 'paused':
    case 'callback':
    case 'callnotattended':
      return AppColors.statusWaiting;
    case 'resolved':
      return AppColors.statusResolved;
    case 'closed':
      return AppColors.statusClosed;
    case 'billraised':
    case 'billprocessed':
      return const Color(0xFFDB2777);
    case 'cancelled':
    case 'canceled':
      return AppColors.error;
    case 'wontpay':
      return const Color(0xFFEA580C);
    default:
      return AppColors.slate500;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is String) {
    final normalized = (value.endsWith('Z') || value.contains('+'))
        ? value
        : '${value}Z';
    return DateTime.tryParse(normalized)?.toUtc();
  }
  return null;
}

DateTime? _firstClaimedAt(dynamic rawHistory) {
  dynamic history = rawHistory;
  if (history is String && history.isNotEmpty) {
    try {
      history = jsonDecode(history);
    } catch (_) {
      return null;
    }
  }
  if (history is! List) return null;

  DateTime? earliest;
  for (final entry in history) {
    if (entry is! Map) continue;
    final claimedAt = _parseDate(entry['assigned_at']);
    if (claimedAt == null) continue;
    if (earliest == null || claimedAt.isBefore(earliest)) {
      earliest = claimedAt;
    }
  }
  return earliest;
}

String _formatDuration(Duration duration) {
  if (duration.isNegative) duration = Duration.zero;
  final minutes = duration.inMinutes;
  if (minutes < 1) return '<1m';
  if (minutes < 60) return '${minutes}m';
  final days = duration.inDays;
  final hours = duration.inHours;
  if (days >= 1) {
    final remHours = hours % 24;
    if (remHours == 0) return '${days}d';
    return '${days}d ${remHours}h';
  }
  final remainder = minutes % 60;
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

String _formatDay(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
