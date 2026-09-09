import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/time_utils.dart';
import '../../domain/entities/task.dart';
import 'common.dart';

/// Read-only task table used by client-detail tabs and the deliverables
/// screen. For the editable inline-update boards (task_board/pending_board)
/// see EditableTaskTable.
class TaskTable extends StatefulWidget {
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
  State<TaskTable> createState() => _TaskTableState();
}

class _TaskTableState extends State<TaskTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(widget.emptyMessage, style: const TextStyle(color: Colors.grey)),
      );
    }

    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withValues(alpha: 0.6);

    const double headingHeight = 56.0;
    const double rowHeight = 52.0;
    const double clientColumnWidth = 190.0;

    if (!widget.showClient) {
      return Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: _buildRightTable(context, headingHeight, rowHeight),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Locked Sticky Client Column
        Container(
          width: clientColumnWidth,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(color: borderColor, width: 1.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: headingHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
                ),
                child: const Text('Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              for (final t in widget.tasks)
                InkWell(
                  onTap: () => context.push('/tasks/${t.id}'),
                  child: Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
                    ),
                    child: Tooltip(
                      message: t.client ?? '-',
                      child: Text(
                        t.client ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Horizontally Scrollable Remaining Columns
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: _buildRightTable(context, headingHeight, rowHeight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightTable(BuildContext context, double headingHeight, double rowHeight) {
    return DataTable(
      horizontalMargin: 16,
      columnSpacing: 24,
      headingRowHeight: headingHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      columns: const [
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('Priority')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Due')),
        DataColumn(label: Text('Assignees')),
        DataColumn(label: Text('Time')),
      ],
      rows: [
        for (final t in widget.tasks)
          DataRow(
            onSelectChanged: (_) => context.push('/tasks/${t.id}'),
            cells: [
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240, minWidth: 160),
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
    );
  }
}
