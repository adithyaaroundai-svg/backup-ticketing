import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/time_utils.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';
import '../providers/task_board_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../widgets/board_chrome.dart';
import '../widgets/common.dart';
import '../widgets/editable_task_table.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/choose_client_dialog.dart';

/// Today's Tasks board (`task_board.ejs`): grouped by date, with
/// assignee/client filters, add-task form, inline editable rows, and a
/// "carry forward unfinished work" bulk action.
class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<TaskBoardProvider>();
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
    return const _TaskBoardBody();
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
    for (final t in prov.filteredTasks) {
      final key = t.taskDate ?? 'No date';
      (grouped[key] ??= []).add(t);
    }

    final emptyMessage = prov.statusFilter == 'completed'
        ? 'No completed tasks found.'
        : prov.statusFilter == 'cancelled'
            ? 'No cancelled tasks found.'
            : 'No active tasks for today.';

    return RefreshIndicator(
      onRefresh: () => prov.load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BoardPageHeader(
              title: "Today's Tasks",
              subtitle: 'Work planned for today, grouped by date.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  BoardStatusCard(
                    label: 'Active',
                    count: prov.activeTasksCount,
                    selected: prov.statusFilter == 'active',
                    color: AppColors.primary,
                    icon: Icons.bolt_rounded,
                    onTap: () => prov.setStatusFilter('active'),
                  ),
                  BoardStatusCard(
                    label: 'Completed',
                    count: prov.completedTasksCount,
                    selected: prov.statusFilter == 'completed',
                    color: AppColors.success,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () => prov.setStatusFilter('completed'),
                  ),
                  BoardStatusCard(
                    label: 'Cancelled',
                    count: prov.cancelledTasksCount,
                    selected: prov.statusFilter == 'cancelled',
                    color: AppColors.slate600,
                    icon: Icons.cancel_outlined,
                    onTap: () => prov.setStatusFilter('cancelled'),
                  ),
                ];
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        cards[i],
                      ],
                    ],
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
            BoardToolbar(
              children: [
                BoardAssigneeFilter(
                  value: prov.assigneeFilter,
                  options: [for (final user in _assigneeOptions) (user.id, user.name)],
                  onChanged: (id) {
                    prov.setAssigneeFilter(id);
                  },
                ),
                _SearchableClientFilter(
                  clients: clientsProv.clients,
                  value: prov.clientFilter,
                  onChanged: (v) => prov.setClientFilter(v),
                ),
                if (prov.statusFilter != 'active' || prov.assigneeFilter != null || prov.clientFilter != null)
                  TextButton(
                    onPressed: () {
                      prov.clearFilters();
                      prov.load();
                    },
                    child: const Text('Clear filters'),
                  ),
                OutlinedButton.icon(
                  icon: _carryingForward
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.forward, size: 18),
                  label: const Text('Carry forward'),
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
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add task'),
                  onPressed: () => _addTask(context, prov, clientsProv.clients),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (grouped.isEmpty) BoardEmptyState(message: emptyMessage),
            for (final entry in grouped.entries) ...[
              BoardDateHeader(
                label: entry.key == 'No date' ? 'No date' : fmtDate(entry.key),
                count: entry.value.length,
              ),
              const SizedBox(height: 8),
              BoardTableCard(
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
    final formResult = await showTaskFormDialog(context, users: _assigneeOptions);
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

class _SearchableClientFilter extends StatefulWidget {
  const _SearchableClientFilter({
    required this.clients,
    required this.value,
    required this.onChanged,
  });

  final List<Client> clients;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_SearchableClientFilter> createState() => _SearchableClientFilterState();
}

class _SearchableClientFilterState extends State<_SearchableClientFilter> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    Client? selected;
    for (final client in widget.clients) {
      if (client.id == widget.value) {
        selected = client;
        break;
      }
    }
    final label = selected?.name ?? 'All clients';

    return MenuAnchor(
      controller: _menu,
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        _ClientFilterMenu(
          clients: widget.clients,
          selectedId: widget.value,
          onSelected: (id) {
            widget.onChanged(id);
            _menu.close();
          },
        ),
      ],
      builder: (context, controller, child) {
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.slate50,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClientFilterMenu extends StatefulWidget {
  const _ClientFilterMenu({
    required this.clients,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Client> clients;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  State<_ClientFilterMenu> createState() => _ClientFilterMenuState();
}

class _ClientFilterMenuState extends State<_ClientFilterMenu> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = widget.clients.where((client) {
      if (query.isEmpty) return true;
      final name = client.name.toLowerCase();
      final contact = client.contact?.toLowerCase() ?? '';
      return name.contains(query) || contact.contains(query);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SizedBox(
      width: 280,
      height: 340,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search clients',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  dense: true,
                  title: const Text('All clients'),
                  selected: widget.selectedId == null,
                  onTap: () => widget.onSelected(null),
                ),
                if (matches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No clients found', style: TextStyle(color: Colors.grey)),
                  )
                else
                  for (final client in matches)
                    ListTile(
                      dense: true,
                      title: Text(client.name),
                      selected: widget.selectedId == client.id,
                      onTap: () => widget.onSelected(client.id),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
