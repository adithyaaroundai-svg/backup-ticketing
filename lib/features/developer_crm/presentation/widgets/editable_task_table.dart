import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../core/enums.dart';
import '../../core/time_utils.dart';
import '../../domain/entities/task.dart';
import 'common.dart';
import 'task_table_column_header.dart';
import 'task_table_filter_models.dart';

/// Editable board row table used by both Today's Tasks and Pending boards:
/// tapping the priority/status dropdown immediately auto-saves via
/// [onQuickUpdate] (`POST /api/tasks/:id/update`), with a "Saved ✓" /
/// "Save failed" snackbar, matching the original EJS board's inline-edit
/// behavior.
///
/// Features column-wise sorting (Asc/Desc/None) and per-column filtering
/// for Client, Description, Priority, Status, Due, Assignees, and Time.
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
              // Locked / Sticky Left Column: Client
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
                    // Client Header with Sort & Filter
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
                    // Client Rows
                    for (var i = 0; i < displayTasks.length; i++)
                      InkWell(
                        onTap: () => context.push('/dev-crm/tasks/${displayTasks[i].id}'),
                        child: Container(
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          color: i.isOdd ? AppColors.slate50 : Colors.white,
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

  /// Description and Assignees grow so the row fills the card. The other
  /// columns stay at a readable minimum.
  List<double> _columnWidths(double available) {
    const mins = <double>[260, 132, 220, 124, 180, 104, 120];
    const flex = <int>[5, 0, 0, 0, 3, 0, 0];
    final minSum = mins.fold<double>(0, (sum, width) => sum + width);
    final flexTotal = flex.fold<int>(0, (sum, value) => sum + value);
    final width = available.isFinite ? available : minSum;
    if (width <= minSum || flexTotal == 0) return mins;
    final extra = width - minSum;
    return [
      for (var i = 0; i < mins.length; i++) mins[i] + extra * (flex[i] / flexTotal),
    ];
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
              _fit(const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
        ),
        for (var i = 0; i < displayTasks.length; i++)
          _TableBand(
            height: rowHeight,
            widths: widths,
            color: i.isOdd ? AppColors.slate50 : Colors.white,
            border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
            children: [
              InkWell(
                onTap: () => context.push('/dev-crm/tasks/${displayTasks[i].id}'),
                child: Tooltip(
                  message: displayTasks[i].description,
                  waitDuration: const Duration(milliseconds: 250),
                  child: Text(
                    displayTasks[i].description,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate700),
                  ),
                ),
              ),
              _PriorityDropdown(
                value: displayTasks[i].priority,
                onChanged: (v) => widget.onQuickUpdate(displayTasks[i].id, priority: v),
              ),
              _StatusDropdown(
                value: displayTasks[i].status,
                onChanged: (v) => widget.onQuickUpdate(displayTasks[i].id, status: v),
              ),
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
              Row(mainAxisSize: MainAxisSize.min, children: widget.rowActionsBuilder(displayTasks[i])),
            ],
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

class _PriorityDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _PriorityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: kPriorities.contains(value) ? value : null,
      underline: const SizedBox.shrink(),
      isExpanded: true,
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
      isExpanded: true,
      isDense: true,
      borderRadius: BorderRadius.circular(10),
      selectedItemBuilder: (context) => [
        for (final status in kAllTaskStatuses)
          Align(
            alignment: Alignment.centerLeft,
            child: _StatusPill(status: status),
          ),
      ],
      items: [
        for (final s in kAllTaskStatuses)
          DropdownMenuItem(
            value: s,
            child: Text(taskStatusLabel(s), style: const TextStyle(fontSize: 13, color: AppColors.slate800)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  Color get _color {
    switch (status) {
      case 'working':
        return AppColors.primary;
      case 'ready_for_testing':
      case 'ready_for_implementation':
        return AppColors.accent;
      case 'awaiting_confirmation':
        return AppColors.statusWaiting;
      case 'completed':
        return AppColors.success;
      case 'paused':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.slate500;
      default:
        return AppColors.slate600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        taskStatusLabel(status),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color),
      ),
    );
  }
}
