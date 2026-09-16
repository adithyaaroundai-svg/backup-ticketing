import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/time_utils.dart';
import '../../domain/entities/task.dart';
import 'common.dart';
import 'task_table_column_header.dart';
import 'task_table_filter_models.dart';

/// Read-only task table used by client-detail tabs and the deliverables
/// screen. For the editable inline-update boards (task_board/pending_board)
/// see EditableTaskTable.
///
/// Supports column-wise sorting and per-column filtering for Client,
/// Description, Priority, Status, Due, Assignees, and Time.
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
  TaskTableFilterState _filterState = const TaskTableFilterState();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFilterState(TaskTableFilterState newState) {
    setState(() {
      _filterState = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(widget.emptyMessage, style: const TextStyle(color: Colors.grey)),
      );
    }

    final displayTasks = _filterState.apply(widget.tasks);
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withValues(alpha: 0.6);

    const double headingHeight = 56.0;
    const double rowHeight = 52.0;
    const double clientColumnWidth = 220.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskTableActiveFiltersBar(
          state: _filterState,
          onStateChanged: _updateFilterState,
          totalCount: widget.tasks.length,
          filteredCount: displayTasks.length,
        ),
        if (displayTasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_off_rounded, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No tasks match the active filters.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _updateFilterState(_filterState.resetAll()),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset table filters'),
                ),
              ],
            ),
          )
        else if (!widget.showClient)
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: _buildRightTable(context, headingHeight, rowHeight, displayTasks),
            ),
          )
        else
          Row(
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
                      ),
                      child: TaskTableColumnHeader(
                        column: TaskColumn.client,
                        state: _filterState,
                        onStateChanged: _updateFilterState,
                        allTasks: widget.tasks,
                      ),
                    ),
                    for (final t in displayTasks)
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
                    child: _buildRightTable(context, headingHeight, rowHeight, displayTasks),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRightTable(BuildContext context, double headingHeight, double rowHeight, List<Task> displayTasks) {
    return DataTable(
      horizontalMargin: 16,
      columnSpacing: 24,
      headingRowHeight: headingHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      columns: [
        DataColumn(
          label: TaskTableColumnHeader(
            column: TaskColumn.description,
            state: _filterState,
            onStateChanged: _updateFilterState,
            allTasks: widget.tasks,
          ),
        ),
        DataColumn(
          label: TaskTableColumnHeader(
            column: TaskColumn.priority,
            state: _filterState,
            onStateChanged: _updateFilterState,
            allTasks: widget.tasks,
          ),
        ),
        DataColumn(
          label: TaskTableColumnHeader(
            column: TaskColumn.status,
            state: _filterState,
            onStateChanged: _updateFilterState,
            allTasks: widget.tasks,
          ),
        ),
        DataColumn(
          label: TaskTableColumnHeader(
            column: TaskColumn.due,
            state: _filterState,
            onStateChanged: _updateFilterState,
            allTasks: widget.tasks,
          ),
        ),
        DataColumn(
          label: TaskTableColumnHeader(
            column: TaskColumn.assignees,
            state: _filterState,
            onStateChanged: _updateFilterState,
            allTasks: widget.tasks,
          ),
        ),
        DataColumn(
          label: TaskTableColumnHeader(
            column: TaskColumn.time,
            state: _filterState,
            onStateChanged: _updateFilterState,
            allTasks: widget.tasks,
          ),
        ),
      ],
      rows: [
        for (final t in displayTasks)
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
