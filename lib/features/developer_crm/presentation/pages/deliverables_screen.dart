import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../providers/deliverables_provider.dart';
import '../widgets/common.dart';
import '../widgets/task_table.dart';

class DeliverablesScreen extends StatelessWidget {
  const DeliverablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DeliverablesProvider(ctx.read<ApiClient>())..load(),
      child: const _DeliverablesBody(),
    );
  }
}

class _DeliverablesBody extends StatelessWidget {
  const _DeliverablesBody();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeliverablesProvider>();
    if (prov.loading && prov.today == null) return const CenterLoading();
    if (prov.error != null && prov.today == null) {
      return ErrorBanner(message: prov.error!, onRetry: prov.load);
    }
    return RefreshIndicator(
      onRefresh: prov.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Deliverables', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _Section(title: 'Due today', child: TaskTable(tasks: prov.todayDue, showClient: true, emptyMessage: 'Nothing due today.')),
          const SizedBox(height: 20),
          _Section(title: 'Due tomorrow', child: TaskTable(tasks: prov.tomorrowDue, showClient: true, emptyMessage: 'Nothing due tomorrow.')),
          const SizedBox(height: 20),
          _Section(title: 'Delayed', child: TaskTable(tasks: prov.delayed, showClient: true, emptyMessage: 'Nothing delayed. \ud83c\udf89')),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(child: child),
      ],
    );
  }
}
