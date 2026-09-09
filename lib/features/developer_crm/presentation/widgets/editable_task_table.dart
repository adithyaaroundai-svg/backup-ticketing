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
class EditableTaskTable extends StatefulWidget {
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
  State<EditableTaskTable> createState() => _EditableTaskTableState();
}

class _EditableTaskTableState extends State<EditableTaskTable> {
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
        // Locked / Sticky Left Column: Client
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
              // Client Header
              Container(
                height: headingHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
                ),
                child: const Text(
                  'Client',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              // Client Rows
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
        DataColumn(label: Text('Actions')),
      ],
      rows: [
        for (final t in widget.tasks)
          DataRow(cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240, minWidth: 160),
                child: Text(t.description, overflow: TextOverflow.ellipsis, maxLines: 2),
              ),
              onTap: () => context.push('/tasks/${t.id}'),
            ),
            DataCell(_PriorityDropdown(
              value: t.priority,
              onChanged: (v) => widget.onQuickUpdate(t.id, priority: v),
            )),
            DataCell(_StatusDropdown(
              value: t.status,
              onChanged: (v) => widget.onQuickUpdate(t.id, status: v),
            )),
            DataCell(Text(t.expectedFinish == null ? '-' : fmtDate(t.expectedFinish))),
            DataCell(Text(t.assignees.map((a) => a.name ?? '#${a.id}').join(', '))),
            DataCell(Text(fmtDuration(t.liveSeconds()))),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: widget.rowActionsBuilder(t))),
          ]),
      ],
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
