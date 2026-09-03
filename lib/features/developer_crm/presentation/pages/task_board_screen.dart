import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/time_utils.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';
import '../providers/task_board_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';
import '../widgets/editable_task_table.dart';
import '../widgets/task_form_dialog.dart';

/// Today's Tasks board (`task_board.ejs`): grouped by date, with
/// assignee/client filters, add-task form, inline editable rows, and a
/// "carry forward unfinished work" bulk action.
class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => TaskBoardProvider()..load()),
        ChangeNotifierProvider(create: (ctx) => ClientsProvider()..load()),
      ],
      child: const _TaskBoardBody(),
    );
  }
}

class _TaskBoardBody extends StatefulWidget {
  const _TaskBoardBody();

  @override
  State<_TaskBoardBody> createState() => _TaskBoardBodyState();
}

class _TaskBoardBodyState extends State<_TaskBoardBody> {
  final ScrollController _horizontalScrollController = ScrollController();
  List<UserRef> _assigneeOptions = [];
  bool _capturedOptions = false;
  bool _carryingForward = false;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

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

  Future<void> _quickUpdate(TaskBoardProvider prov, Task task, AuthProvider authProv, {String? priority, String? status}) async {
    try {
      await prov.quickUpdate(
        task.id,
        priority: priority,
        status: status,
        taskDescription: task.description,
        currentUserId: authProv.user?.id,
        currentUserName: authProv.user?.name,
      );
      if (mounted) showSavedSnack(context, ok: true);
    } catch (e) {
      if (mounted) showSavedSnack(context, ok: false, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TaskBoardProvider>();
    final clientsProv = context.watch<ClientsProvider>();
    final authProv = context.watch<AuthProvider>();
    _maybeCaptureAssigneeOptions(prov.tasks);

    if (prov.loading && prov.tasks.isEmpty) return const CenterLoading();
    if (prov.error != null && prov.tasks.isEmpty) {
      return ErrorBanner(message: prov.error!, onRetry: () => prov.load());
    }

    final grouped = LinkedHashMap<String, List<Task>>();
    for (final t in prov.tasks) {
      final key = t.taskDate ?? 'No date';
      (grouped[key] ??= []).add(t);
    }

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
                onRefresh: () => prov.load(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text("Today's Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              DropdownButton<int?>(
                hint: const Text('All assignees'),
                value: prov.assigneeFilter,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All assignees')),
                  for (final u in _assigneeOptions) DropdownMenuItem<int?>(value: u.id, child: Text(u.name)),
                ],
                onChanged: (v) => prov.load(assignee: v),
              ),
              DropdownButton<int?>(
                hint: const Text('All clients'),
                value: prov.clientFilter,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All clients')),
                  for (final c in clientsProv.clients)
                    DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => prov.load(client: v),
              ),
              if (prov.assigneeFilter != null || prov.clientFilter != null)
                TextButton(
                  onPressed: () {
                    prov.clearFilters();
                    prov.load();
                  },
                  child: const Text('Clear filters'),
                ),
              // Spacer removed because it crashes inside Wrap
              OutlinedButton.icon(
                icon: _carryingForward
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.forward),
                label: const Text('Carry forward unfinished work'),
                onPressed: _carryingForward
                    ? null
                    : () async {
                        setState(() => _carryingForward = true);
                        try {
                          final count = await prov.carryForwardAll(currentUserId: authProv.user?.id, currentUserName: authProv.user?.name);
                          if (mounted) showSavedSnack(context, message: 'Carried forward $count task(s) \u2713');
                        } catch (e) {
                          if (mounted) showSavedSnack(context, ok: false, message: e.toString());
                        } finally {
                          if (mounted) setState(() => _carryingForward = false);
                        }
                      },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add task'),
                onPressed: () => _addTask(context, prov, clientsProv.clients),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in grouped.entries) ...[
            Text(
              entry.key == 'No date' ? 'No date' : fmtDate(entry.key),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Card(
              child: EditableTaskTable(
                tasks: entry.value,
                onQuickUpdate: (id, {priority, status}) {
                  final task = entry.value.firstWhere((t) => t.id == id);
                  return _quickUpdate(prov, task, authProv, priority: priority, status: status);
                },
                rowActionsBuilder: (task) => [
                  IconButton(
                    tooltip: 'Move to pending',
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    onPressed: () async {
                      try {
                        await prov.toPending(task.id, taskDescription: task.description, currentUserId: authProv.user?.id, currentUserName: authProv.user?.name);
                        if (mounted) showSavedSnack(context, message: 'Moved to pending \u2713');
                      } catch (e) {
                        if (mounted) showSavedSnack(context, ok: false, message: e.toString());
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Carry forward to today',
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () async {
                      try {
                        await prov.carryForwardOne(task.id, taskDescription: task.description, currentUserId: authProv.user?.id, currentUserName: authProv.user?.name);
                        if (mounted) showSavedSnack(context, message: 'Moved to today \u2713');
                      } catch (e) {
                        if (mounted) showSavedSnack(context, ok: false, message: e.toString());
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
                      if (grouped.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No tasks for today.', style: TextStyle(color: Colors.grey)),
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
    final formResult = await showTaskFormDialog(context, users: _assigneeOptions);
    if (formResult == null) return;
    try {
      final authProv = context.read<AuthProvider>();
      final clientName = clients.firstWhere(
        (c) => c.id == clientId,
        orElse: () => Client(id: clientId, name: ''),
      ).name;

      await prov.createTask(
        clientId: clientId,
        clientName: clientName,
        description: formResult.description,
        priority: formResult.priority,
        status: formResult.status,
        expectedFinish: formResult.expectedFinish,
        startDate: formResult.startDate,
        approved: formResult.approved,
        pending: formResult.pending,
        assigneeIds: formResult.assigneeIds,
        files: formResult.files,
        currentUserId: authProv.user?.id,
        currentUserName: authProv.user?.name,
      );
      if (context.mounted) showSavedSnack(context, message: 'Task created \u2713');
    } catch (e) {
      if (context.mounted) showSavedSnack(context, ok: false, message: e.toString());
    }
  }
}
