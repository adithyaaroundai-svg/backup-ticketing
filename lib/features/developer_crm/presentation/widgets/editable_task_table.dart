import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../core/time_utils.dart';
import '../../domain/entities/task.dart';
import 'common.dart';

/// Editable board row table used by both Today's Tasks and Pending boards:
/// tapping the priority/status dropdown immediately auto-saves via
/// [onQuickUpdate] (`POST /api/tasks/:id/update`), with a "Saved ✓" /
/// "Save failed" snackbar, matching the original EJS board's inline-edit
/// behavior.
class EditableTaskTable extends StatelessWidget {
  final List<Task> tasks;
  final bool showClient;
  final Future<void> Function(int taskId, {String? priority, String? status}) onQuickUpdate;
  final List<Widget> Function(Task task) rowActionsBuilder;
  final String emptyMessage;

  const EditableTaskTable({
    super.key,
    required this.tasks,
    required this.onQuickUpdate,
    required this.rowActionsBuilder,
    this.showClient = true,
    this.emptyMessage = 'No tasks.',
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          if (showClient) const DataColumn(label: Text('Client')),
          const DataColumn(label: Text('Description')),
          const DataColumn(label: Text('Priority')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Due')),
          const DataColumn(label: Text('Assignees')),
          const DataColumn(label: Text('Time')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final t in tasks)
            DataRow(cells: [
              if (showClient)
                DataCell(
                  Text(t.client ?? '-'),
                  onTap: () => context.push('/tasks/${t.id}'),
                ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(t.description, overflow: TextOverflow.ellipsis, maxLines: 2),
                ),
                onTap: () => context.push('/tasks/${t.id}'),
              ),
              DataCell(_PriorityDropdown(
                value: t.priority,
                onChanged: (v) => onQuickUpdate(t.id, priority: v),
              )),
              DataCell(_StatusDropdown(
                value: t.status,
                onChanged: (v) => onQuickUpdate(t.id, status: v),
              )),
              DataCell(Text(t.expectedFinish == null ? '-' : fmtDate(t.expectedFinish))),
              DataCell(Text(t.assignees.map((a) => a.name ?? '#${a.id}').join(', '))),
              DataCell(Text(fmtDuration(t.liveSeconds()))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: rowActionsBuilder(t))),
            ]),
        ],
      ),
    );
  }
}

class _PriorityDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _PriorityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: kPriorities.contains(value) ? value : null,
      underline: const SizedBox.shrink(),
      items: [for (final p in kPriorities) DropdownMenuItem(value: p, child: PriorityChip(priority: p))],
      onChanged: onChanged,
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: kAllTaskStatuses.contains(value) ? value : null,
      underline: const SizedBox.shrink(),
      items: [
        for (final s in kAllTaskStatuses)
          DropdownMenuItem(value: s, child: Text(taskStatusLabel(s), style: const TextStyle(fontSize: 12)))
      ],
      onChanged: onChanged,
    );
  }
}
