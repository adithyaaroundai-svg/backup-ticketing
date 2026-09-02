import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/time_utils.dart';
import '../../domain/entities/task.dart';
import 'common.dart';

/// Read-only task table used by client-detail tabs and the deliverables
/// screen. For the editable inline-update boards (task_board/pending_board)
/// see EditableTaskTable.
class TaskTable extends StatelessWidget {
  final List<Task> tasks;
  final bool showClient;
  final String emptyMessage;

  const TaskTable({
    super.key,
    required this.tasks,
    this.showClient = false,
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
        ],
        rows: [
          for (final t in tasks)
            DataRow(
              onSelectChanged: (_) => context.push('/tasks/${t.id}'),
              cells: [
                if (showClient) DataCell(Text(t.client ?? '-')),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(t.description, overflow: TextOverflow.ellipsis, maxLines: 2),
                )),
                DataCell(PriorityChip(priority: t.priority)),
                DataCell(StatusChip(status: t.status)),
                DataCell(Text(t.expectedFinish == null ? '-' : fmtDate(t.expectedFinish))),
                DataCell(Text(t.assignees.map((a) => a.name ?? '#${a.id}').join(', '))),
                DataCell(Text(fmtDuration(t.liveSeconds()))),
              ],
            ),
        ],
      ),
    );
  }
}
