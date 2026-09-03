import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/time_utils.dart';
import '../providers/activity_provider.dart';
import '../widgets/common.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ActivityProvider()..load(),
      child: const _ActivityBody(),
    );
  }
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ActivityProvider>();
    if (prov.loading && prov.entries.isEmpty) return const CenterLoading();
    if (prov.error != null && prov.entries.isEmpty) {
      return ErrorBanner(message: prov.error!, onRetry: prov.load);
    }
    return RefreshIndicator(
      onRefresh: prov.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Activity log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Last 300 entries, newest first.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prov.entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = prov.entries[i];
                return ListTile(
                  title: Text(e.message),
                  subtitle: Text('${e.userName ?? 'System'} \u2022 ${fmtDateTimeIst(e.createdAt)}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
