import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/theme/app_colors.dart';
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

  Widget _fit(Widget child) {
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: child);
  }

  Widget _headerFor(TaskColumn column) {
    return TaskTableColumnHeader(
      column: column,
      state: _filterState,
      onStateChanged: _updateFilterState,
      allTasks: widget.tasks,
    );
  }

  List<double> _columnWidths(double available) {
    const mins = <double>[260, 110, 130, 120, 180, 100];
    const flex = <int>[5, 0, 0, 0, 2, 0];
    final minSum = mins.fold<double>(0, (sum, width) => sum + width);
    final flexTotal = flex.fold<int>(0, (sum, value) => sum + value);
    final width = available.isFinite ? available : minSum;
    if (width <= minSum || flexTotal == 0) return mins;
    final extra = width - minSum;
    return [
      for (var i = 0; i < mins.length; i++) mins[i] + extra * (flex[i] / flexTotal),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Text(widget.emptyMessage, style: const TextStyle(color: Colors.grey)),
      );
    }

    final displayTasks = _filterState.apply(widget.tasks);
    final theme = Theme.of(context);

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
          LayoutBuilder(
            builder: (context, constraints) {
              return _buildRightTable(context, headingHeight, rowHeight, displayTasks, constraints.maxWidth);
            },
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
                  border: const Border(
                    right: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: headingHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: const BoxDecoration(
                        color: AppColors.slate100,
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: TaskTableColumnHeader(
                        column: TaskColumn.client,
                        state: _filterState,
                        onStateChanged: _updateFilterState,
                        allTasks: widget.tasks,
                      ),
                    ),
                    for (var i = 0; i < displayTasks.length; i++)
                      InkWell(
                        onTap: () => context.push('/dev-crm/tasks/${displayTasks[i].id}'),
                        child: Container(
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: i.isOdd ? AppColors.slate50 : Colors.white,
                            border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
                          ),
                          child: Tooltip(
                            message: displayTasks[i].client ?? '-',
                            child: Text(
                              displayTasks[i].client ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Expanded remaining columns that fill the rest of the available width
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildRightTable(
                      context,
                      headingHeight,
                      rowHeight,
                      displayTasks,
                      constraints.maxWidth,
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRightTable(
    BuildContext context,
    double headingHeight,
    double rowHeight,
    List<Task> displayTasks,
    double availableWidth,
  ) {
    final widths = _columnWidths(availableWidth);
    final tableWidth = widths.fold<double>(0, (sum, width) => sum + width);
    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TableBand(
          height: headingHeight,
          widths: widths,
          color: AppColors.slate100,
          border: const Border(bottom: BorderSide(color: AppColors.border)),
          children: [
            _fit(_headerFor(TaskColumn.description)),
            _fit(_headerFor(TaskColumn.priority)),
            _fit(_headerFor(TaskColumn.status)),
            _fit(_headerFor(TaskColumn.due)),
            _fit(_headerFor(TaskColumn.assignees)),
            _fit(_headerFor(TaskColumn.time)),
          ],
        ),
        for (var i = 0; i < displayTasks.length; i++)
          InkWell(
            onTap: () => context.push('/dev-crm/tasks/${displayTasks[i].id}'),
            child: _TableBand(
              height: rowHeight,
              widths: widths,
              color: i.isOdd ? AppColors.slate50 : Colors.white,
              border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
              children: [
                Tooltip(
                  message: displayTasks[i].description,
                  waitDuration: const Duration(milliseconds: 250),
                  child: Text(
                    displayTasks[i].description,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate700),
                  ),
                ),
                PriorityChip(priority: displayTasks[i].priority),
                StatusChip(status: displayTasks[i].status),
                Text(
                  displayTasks[i].expectedFinish == null ? '-' : fmtDate(displayTasks[i].expectedFinish),
                  style: const TextStyle(fontSize: 13, color: AppColors.slate700),
                ),
                Tooltip(
                  message: displayTasks[i].assignees.map((a) => a.name ?? '#${a.id}').join(', '),
                  waitDuration: const Duration(milliseconds: 250),
                  child: Text(
                    displayTasks[i].assignees.map((a) => a.name ?? '#${a.id}').join(', '),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate700),
                  ),
                ),
                Text(
                  fmtDuration(displayTasks[i].liveSeconds()),
                  style: const TextStyle(fontSize: 13, color: AppColors.slate700),
                ),
              ],
            ),
          ),
      ],
    );

    if (availableWidth.isFinite && availableWidth + 1 >= tableWidth) return table;
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: tableWidth, child: table),
      ),
    );
  }
}

class _TableBand extends StatelessWidget {
  const _TableBand({
    required this.height,
    required this.widths,
    required this.children,
    required this.color,
    required this.border,
  });

  final double height;
  final List<double> widths;
  final List<Widget> children;
  final Color color;
  final Border border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: color, border: border),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(alignment: Alignment.centerLeft, child: children[i]),
              ),
            ),
        ],
      ),
    );
  }
}
