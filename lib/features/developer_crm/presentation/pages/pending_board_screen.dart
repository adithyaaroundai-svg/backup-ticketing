import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';
import '../providers/clients_provider.dart';
import '../providers/task_board_provider.dart';
import '../widgets/common.dart';
import '../widgets/editable_task_table.dart';
import '../widgets/task_form_dialog.dart';

/// Pending Tasks board (`pending_board.ejs`).
class PendingBoardScreen extends StatelessWidget {
  const PendingBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => TaskBoardProvider(ctx.read<ApiClient>(), pendingBoard: true)..load(),
        ),
        ChangeNotifierProvider(create: (ctx) => ClientsProvider(ctx.read<ApiClient>())..load()),
      ],
      child: const _PendingBoardBody(),
    );
  }
}

class _PendingBoardBody extends StatefulWidget {
  const _PendingBoardBody();

  @override
  State<_PendingBoardBody> createState() => _PendingBoardBodyState();
}

class _PendingBoardBodyState extends State<_PendingBoardBody> {
  List<UserRef> _assigneeOptions = [];
  bool _capturedOptions = false;

  void _maybeCaptureAssigneeOptions(List<Task> tasks) {
    if (_capturedOptions) return;
    final seen = <int, UserRef>{};
    for (final t in tasks) {
      for (final a in t.assignees) {
        seen[a.id] = UserRef(id: a.id, name: a.name ?? '#${a.id}');
      }
    }
    if (seen.isNotEmpty) {
      _assigneeOptions = seen.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      _capturedOptions = true;
    }
  }

  Future<void> _quickUpdate(TaskBoardProvider prov, int taskId, {String? priority, String? status}) async {
    try {
      await prov.quickUpdate(taskId, priority: priority, status: status);
      if (mounted) showSavedSnack(context, ok: true);
    } catch (e) {
      if (mounted) showSavedSnack(context, ok: false, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TaskBoardProvider>();
    final clientsProv = context.watch<ClientsProvider>();
    _maybeCaptureAssigneeOptions(prov.tasks);

    if (prov.loading && prov.tasks.isEmpty) return const CenterLoading();
    if (prov.error != null && prov.tasks.isEmpty) {
      return ErrorBanner(message: prov.error!, onRetry: () => prov.load());
    }

    return RefreshIndicator(
      onRefresh: () => prov.load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text('Pending Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              DropdownButton<int?>(
                hint: const Text('All assignees'),
                value: prov.assigneeFilter,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All assignees')),
                  for (final u in _assigneeOptions) DropdownMenuItem<int?>(value: u.id, child: Text(u.name)),
                ],
                onChanged: (v) => prov.load(assignee: v),
              ),
              if (prov.assigneeFilter != null)
                TextButton(
                  onPressed: () {
                    prov.clearFilters();
                    prov.load();
                  },
                  child: const Text('Clear filter'),
                ),
              // Spacer removed because it crashes inside Wrap
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add pending task'),
                onPressed: () => _addTask(context, prov, clientsProv.clients),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: EditableTaskTable(
              tasks: prov.tasks,
              emptyMessage: 'No pending tasks.',
              onQuickUpdate: (id, {priority, status}) =>
                  _quickUpdate(prov, id, priority: priority, status: status),
              rowActionsBuilder: (task) => [
                IconButton(
                  tooltip: 'Move to today',
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: () async {
                    try {
                      await prov.activate(task.id);
                      if (mounted) showSavedSnack(context, message: 'Moved to today \u2713');
                    } catch (e) {
                      if (mounted) showSavedSnack(context, ok: false, message: e.toString());
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTask(BuildContext context, TaskBoardProvider prov, List<Client> clients) async {
    if (clients.isEmpty) {
      showSavedSnack(context, ok: false, message: 'Create a client first.');
      return;
    }
    int? selectedClientId = clients.first.id;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('Choose client'),
          content: DropdownButtonFormField<int>(
            initialValue: selectedClientId,
            items: [for (final c in clients) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => selectedClientId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, {'clientId': selectedClientId}),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final clientId = result['clientId'] as int;
    final formResult = await showTaskFormDialog(context, users: _assigneeOptions, initialPending: true);
    if (formResult == null) return;
    try {
      await prov.createTask(
        clientId: clientId,
        description: formResult.description,
        priority: formResult.priority,
        status: formResult.status,
        expectedFinish: formResult.expectedFinish,
        startDate: formResult.startDate,
        approved: formResult.approved,
        pending: true,
        assigneeIds: formResult.assigneeIds,
        files: formResult.files,
      );
      if (context.mounted) showSavedSnack(context, message: 'Pending task created \u2713');
    } catch (e) {
      if (context.mounted) showSavedSnack(context, ok: false, message: e.toString());
    }
  }
}
