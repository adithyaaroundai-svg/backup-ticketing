import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/client.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';
import '../providers/task_board_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';
import '../widgets/editable_task_table.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/choose_client_dialog.dart';

/// Pending Tasks board (`pending_board.ejs`).
class PendingBoardScreen extends StatefulWidget {
  const PendingBoardScreen({super.key});

  @override
  State<PendingBoardScreen> createState() => _PendingBoardScreenState();
}

class _PendingBoardScreenState extends State<PendingBoardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<PendingBoardProvider>();
        if (prov.tasks.isEmpty && !prov.loading) {
          prov.load();
        }
        final clientsProv = context.read<ClientsProvider>();
        if (clientsProv.clients.isEmpty && !clientsProv.loading) {
          clientsProv.load();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _PendingBoardBody();
  }
}

class _PendingBoardBody extends StatefulWidget {
  const _PendingBoardBody();

  @override
  State<_PendingBoardBody> createState() => _PendingBoardBodyState();
}

class _PendingBoardBodyState extends State<_PendingBoardBody> {
  final ScrollController _horizontalScrollController = ScrollController();
  List<UserRef> _assigneeOptions = [];
  bool _capturedOptions = false;

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
    final prov = context.watch<PendingBoardProvider>();
    final clientsProv = context.watch<ClientsProvider>();
    final authProv = context.watch<AuthProvider>();
    _maybeCaptureAssigneeOptions(prov.tasks);

    if (prov.loading && prov.tasks.isEmpty) return const CenterLoading();
    if (prov.error != null && prov.tasks.isEmpty) {
      return ErrorBanner(message: prov.error!, onRetry: () => prov.load());
    }

    return RefreshIndicator(
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
                const Text('Pending Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment<String>(
                      value: 'active',
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text('Active (${prov.activeTasksCount})'),
                    ),
                    ButtonSegment<String>(
                      value: 'completed',
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text('Completed (${prov.completedTasksCount})'),
                    ),
                    ButtonSegment<String>(
                      value: 'cancelled',
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: Text('Cancelled (${prov.cancelledTasksCount})'),
                    ),
                  ],
                  selected: {prov.statusFilter},
                  onSelectionChanged: (set) => prov.setStatusFilter(set.first),
                ),
                DropdownButton<int?>(
                  hint: const Text('All assignees'),
                  value: prov.assigneeFilter,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All assignees')),
                    for (final u in _assigneeOptions) DropdownMenuItem<int?>(value: u.id, child: Text(u.name)),
                  ],
                  onChanged: (v) => prov.load(assignee: v),
                ),
                if (prov.statusFilter != 'active' || prov.assigneeFilter != null)
                  TextButton(
                    onPressed: () {
                      prov.clearFilters();
                      prov.load();
                    },
                    child: const Text('Clear filters'),
                  ),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add pending task'),
                  onPressed: () => _addTask(context, prov, clientsProv.clients),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: EditableTaskTable(
                tasks: prov.filteredTasks,
                emptyMessage: prov.statusFilter == 'completed'
                    ? 'No completed pending tasks.'
                    : prov.statusFilter == 'cancelled'
                        ? 'No cancelled pending tasks.'
                        : 'No active pending tasks.',
                onQuickUpdate: (id, {priority, status}) {
                  final task = prov.filteredTasks.firstWhere((t) => t.id == id);
                  return _quickUpdate(prov, task, authProv, priority: priority, status: status);
                },
                rowActionsBuilder: (task) => [
                  IconButton(
                    tooltip: 'Move to today',
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    onPressed: () async {
                      try {
                        await prov.activate(task.id, taskDescription: task.description, currentUserId: authProv.user?.id, currentUserName: authProv.user?.name);
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
      ),
    );
  }

  Future<void> _addTask(BuildContext context, TaskBoardProvider prov, List<Client> clients) async {
    if (clients.isEmpty) {
      showSavedSnack(context, ok: false, message: 'Create a client first.');
      return;
    }
    final clientId = await showChooseClientDialog(context, clients: clients);
    if (clientId == null || !mounted) return;
    final formResult = await showTaskFormDialog(context, users: _assigneeOptions, initialPending: true);
    if (formResult == null || !mounted) return;
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
        pending: true,
        assigneeIds: formResult.assigneeIds,
        files: formResult.files,
        currentUserId: authProv.user?.id,
        currentUserName: authProv.user?.name,
      );
      if (context.mounted) showSavedSnack(context, message: 'Pending task created \u2713');
    } catch (e) {
      if (context.mounted) showSavedSnack(context, ok: false, message: e.toString());
    }
  }
}
