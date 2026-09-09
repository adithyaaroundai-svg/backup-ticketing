import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/enums.dart';
import '../../core/time_utils.dart';
import '../providers/team_provider.dart';
import '../widgets/common.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<TeamProvider>();
        if (prov.team.isEmpty && !prov.loading) {
          prov.load();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _TeamBody();
  }
}

class _TeamBody extends StatefulWidget {
  const _TeamBody();

  @override
  State<_TeamBody> createState() => _TeamBodyState();
}

class _TeamBodyState extends State<_TeamBody> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Ticks once a second so any `running` task's live elapsed time updates
    // continuously, mirroring the original board's client-side timer.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeamProvider>();
    if (prov.loading && prov.team.isEmpty) return const CenterLoading();
    if (prov.error != null && prov.team.isEmpty) {
      return ErrorBanner(message: prov.error!, onRetry: prov.load);
    }
    return RefreshIndicator(
      onRefresh: prov.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Team', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (final m in prov.team)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(m.role.replaceAll('_', ' '), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        Chip(label: Text('Total: ${fmtDuration(m.total)}')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (m.tasks.isEmpty)
                      const Text('No active or logged tasks.', style: TextStyle(color: Colors.grey))
                    else
                      for (final t in m.tasks)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${t.client ?? '-'} \u2022 ${taskStatusLabel(t.status)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (t.running)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.play_circle, color: Colors.green, size: 16),
                                ),
                              Text(fmtDuration(t.liveSeconds())),
                            ],
                          ),
                          onTap: () => context.push('/tasks/${t.id}'),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
