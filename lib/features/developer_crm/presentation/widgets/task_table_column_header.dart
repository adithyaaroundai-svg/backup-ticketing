import 'package:flutter/material.dart';
import '../../core/enums.dart';
import '../../domain/entities/task.dart';
import 'task_table_filter_models.dart';

class TaskTableColumnHeader extends StatelessWidget {
  final TaskColumn column;
  final TaskTableFilterState state;
  final ValueChanged<TaskTableFilterState> onStateChanged;
  final List<Task> allTasks;

  const TaskTableColumnHeader({
    super.key,
    required this.column,
    required this.state,
    required this.onStateChanged,
    required this.allTasks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSorted = state.isColumnSorted(column);
    final isFiltered = state.isColumnFiltered(column);
    final isAsc = state.sortDirection == SortDirection.asc;

    final activeColor = theme.colorScheme.primary;
    final defaultColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8) ?? Colors.black87;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Clickable header title + sort arrow
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            onStateChanged(state.toggleSort(column));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  column.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSorted || isFiltered ? activeColor : defaultColor,
                  ),
                ),
                const SizedBox(width: 4),
                if (isSorted)
                  Icon(
                    isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14,
                    color: activeColor,
                  )
                else
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 14,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),
        // Filter menu button
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                isFiltered ? Icons.filter_alt_rounded : Icons.filter_list_rounded,
                size: 15,
                color: isFiltered ? activeColor : Colors.grey.shade500,
              ),
              if (isFiltered)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Filter & Sort ${column.label}',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          splashRadius: 16,
          onPressed: () => _openFilterDialog(context),
        ),
      ],
    );
  }

  void _openFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _ColumnFilterDialog(
          column: column,
          initialState: state,
          allTasks: allTasks,
          onApply: (newState) {
            onStateChanged(newState);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }
}

class _ColumnFilterDialog extends StatefulWidget {
  final TaskColumn column;
  final TaskTableFilterState initialState;
  final List<Task> allTasks;
  final ValueChanged<TaskTableFilterState> onApply;

  const _ColumnFilterDialog({
    required this.column,
    required this.initialState,
    required this.allTasks,
    required this.onApply,
  });

  @override
  State<_ColumnFilterDialog> createState() => _ColumnFilterDialogState();
}

class _ColumnFilterDialogState extends State<_ColumnFilterDialog> {
  late TaskTableFilterState _state;
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    if (widget.column == TaskColumn.client) {
      _searchCtrl = TextEditingController(text: _state.clientSearch);
    } else if (widget.column == TaskColumn.description) {
      _searchCtrl = TextEditingController(text: _state.descriptionSearch);
    } else {
      _searchCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _getDistinctClients() {
    final clients = <String>{};
    for (final t in widget.allTasks) {
      if (t.client != null && t.client!.trim().isNotEmpty) {
        clients.add(t.client!.trim());
      }
    }
    return clients.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _getDistinctAssignees() {
    final names = <String>{};
    for (final t in widget.allTasks) {
      for (final a in t.assignees) {
        final name = a.name ?? '#${a.id}';
        if (name.trim().isNotEmpty) names.add(name.trim());
      }
    }
    return names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered = _state.isColumnFiltered(widget.column);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list_rounded, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.column.label} Filter & Sort',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const Divider(height: 20),

              // Sort Section
              _buildSortSection(theme),
              const SizedBox(height: 14),

              // Column Specific Filter Section
              const Text(
                'Filter Options',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildColumnFilterBody(),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isFiltered)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _state = _state.clearColumnFilter(widget.column);
                          if (widget.column == TaskColumn.client || widget.column == TaskColumn.description) {
                            _searchCtrl.clear();
                          }
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Reset filter'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          // commit search text
                          if (widget.column == TaskColumn.client) {
                            _state = _state.copyWith(clientSearch: _searchCtrl.text);
                          } else if (widget.column == TaskColumn.description) {
                            _state = _state.copyWith(descriptionSearch: _searchCtrl.text);
                          }
                          widget.onApply(_state);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortSection(ThemeData theme) {
    String ascLabel;
    String descLabel;

    switch (widget.column) {
      case TaskColumn.client:
      case TaskColumn.description:
      case TaskColumn.assignees:
        ascLabel = 'A → Z (Ascending)';
        descLabel = 'Z → A (Descending)';
        break;
      case TaskColumn.priority:
        ascLabel = 'A+ → A → B (High to Low)';
        descLabel = 'B → A → A+ (Low to High)';
        break;
      case TaskColumn.status:
        ascLabel = 'Workflow order (Yet to start → Done)';
        descLabel = 'Reverse workflow order';
        break;
      case TaskColumn.due:
        ascLabel = 'Earliest first';
        descLabel = 'Latest first';
        break;
      case TaskColumn.time:
        ascLabel = 'Shortest first';
        descLabel = 'Longest first';
        break;
    }

    final isAsc = _state.sortColumn == widget.column && _state.sortDirection == SortDirection.asc;
    final isDesc = _state.sortColumn == widget.column && _state.sortDirection == SortDirection.desc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sort Order',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text(ascLabel),
              avatar: isAsc ? const Icon(Icons.arrow_upward_rounded, size: 14) : null,
              selected: isAsc,
              onSelected: (selected) {
                setState(() {
                  _state = _state.copyWith(
                    sortColumn: () => selected ? widget.column : null,
                    sortDirection: selected ? SortDirection.asc : SortDirection.none,
                  );
                });
              },
            ),
            ChoiceChip(
              label: Text(descLabel),
              avatar: isDesc ? const Icon(Icons.arrow_downward_rounded, size: 14) : null,
              selected: isDesc,
              onSelected: (selected) {
                setState(() {
                  _state = _state.copyWith(
                    sortColumn: () => selected ? widget.column : null,
                    sortDirection: selected ? SortDirection.desc : SortDirection.none,
                  );
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColumnFilterBody() {
    switch (widget.column) {
      case TaskColumn.client:
        return _buildClientFilter();
      case TaskColumn.description:
        return _buildDescriptionFilter();
      case TaskColumn.priority:
        return _buildPriorityFilter();
      case TaskColumn.status:
        return _buildStatusFilter();
      case TaskColumn.due:
        return _buildDueFilter();
      case TaskColumn.assignees:
        return _buildAssigneesFilter();
      case TaskColumn.time:
        return _buildTimeFilter();
    }
  }

  Widget _buildClientFilter() {
    final distinctClients = _getDistinctClients();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search client name...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (val) {
            _state = _state.copyWith(clientSearch: val);
          },
        ),
        if (distinctClients.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Select Specific Clients:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final client in distinctClients)
                  CheckboxListTile(
                    title: Text(client, style: const TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    value: _state.selectedClients.contains(client),
                    onChanged: (checked) {
                      final updated = Set<String>.from(_state.selectedClients);
                      if (checked == true) {
                        updated.add(client);
                      } else {
                        updated.remove(client);
                      }
                      setState(() {
                        _state = _state.copyWith(selectedClients: updated);
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Filter by keyword in description...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (val) {
            _state = _state.copyWith(descriptionSearch: val);
          },
        ),
      ],
    );
  }

  Widget _buildPriorityFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in kPriorities)
          CheckboxListTile(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Priority $p', style: const TextStyle(fontSize: 13)),
              ],
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            value: _state.selectedPriorities.contains(p),
            onChanged: (checked) {
              final updated = Set<String>.from(_state.selectedPriorities);
              if (checked == true) {
                updated.add(p);
              } else {
                updated.remove(p);
              }
              setState(() {
                _state = _state.copyWith(selectedPriorities: updated);
              });
            },
          ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in kAllTaskStatuses)
          CheckboxListTile(
            title: Text(taskStatusLabel(s), style: const TextStyle(fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            value: _state.selectedStatuses.contains(s),
            onChanged: (checked) {
              final updated = Set<String>.from(_state.selectedStatuses);
              if (checked == true) {
                updated.add(s);
              } else {
                updated.remove(s);
              }
              setState(() {
                _state = _state.copyWith(selectedStatuses: updated);
              });
            },
          ),
      ],
    );
  }

  Widget _buildDueFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final opt in DueFilterOption.values)
          ListTile(
            title: Text(opt.label, style: const TextStyle(fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: Radio<DueFilterOption>(
              value: opt,
              // ignore: deprecated_member_use
              groupValue: _state.dueFilter,
              // ignore: deprecated_member_use
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _state = _state.copyWith(dueFilter: val);
                  });
                }
              },
            ),
            onTap: () {
              setState(() {
                _state = _state.copyWith(dueFilter: opt);
              });
            },
          ),
      ],
    );
  }

  Widget _buildAssigneesFilter() {
    final assignees = _getDistinctAssignees();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Include unassigned tasks', style: TextStyle(fontSize: 13)),
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          value: _state.includeUnassigned,
          onChanged: (checked) {
            setState(() {
              _state = _state.copyWith(includeUnassigned: checked ?? true);
            });
          },
        ),
        if (assignees.isNotEmpty) ...[
          const Divider(height: 12),
          const Text('Filter by Assignee:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final name in assignees)
                  CheckboxListTile(
                    title: Text(name, style: const TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    value: _state.selectedAssignees.contains(name),
                    onChanged: (checked) {
                      final updated = Set<String>.from(_state.selectedAssignees);
                      if (checked == true) {
                        updated.add(name);
                      } else {
                        updated.remove(name);
                      }
                      setState(() {
                        _state = _state.copyWith(selectedAssignees: updated);
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final opt in TimeFilterOption.values)
          ListTile(
            title: Text(opt.label, style: const TextStyle(fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: Radio<TimeFilterOption>(
              value: opt,
              // ignore: deprecated_member_use
              groupValue: _state.timeFilter,
              // ignore: deprecated_member_use
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _state = _state.copyWith(timeFilter: val);
                  });
                }
              },
            ),
            onTap: () {
              setState(() {
                _state = _state.copyWith(timeFilter: opt);
              });
            },
          ),
      ],
    );
  }
}

class TaskTableActiveFiltersBar extends StatelessWidget {
  final TaskTableFilterState state;
  final ValueChanged<TaskTableFilterState> onStateChanged;
  final int totalCount;
  final int filteredCount;

  const TaskTableActiveFiltersBar({
    super.key,
    required this.state,
    required this.onStateChanged,
    required this.totalCount,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.hasActiveFilters && !state.hasActiveSort) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];

    // Sorted chip
    if (state.hasActiveSort) {
      final col = state.sortColumn!;
      final isAsc = state.sortDirection == SortDirection.asc;
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(isAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
          label: Text('Sorted: ${col.label} (${isAsc ? 'Asc' : 'Desc'})', style: const TextStyle(fontSize: 12)),
          onDeleted: () {
            onStateChanged(state.copyWith(
              sortColumn: () => null,
              sortDirection: SortDirection.none,
            ));
          },
        ),
      );
    }

    // Client filter chip
    if (state.clientSearch.isNotEmpty) {
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Client: "${state.clientSearch}"', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(clientSearch: '')),
        ),
      );
    }
    if (state.selectedClients.isNotEmpty) {
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Clients: ${state.selectedClients.join(", ")}', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(selectedClients: const {})),
        ),
      );
    }

    // Description filter chip
    if (state.descriptionSearch.isNotEmpty) {
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Desc: "${state.descriptionSearch}"', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(descriptionSearch: '')),
        ),
      );
    }

    // Priority filter chip
    if (state.selectedPriorities.isNotEmpty) {
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Priority: ${state.selectedPriorities.join(", ")}', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(selectedPriorities: const {})),
        ),
      );
    }

    // Status filter chip
    if (state.selectedStatuses.isNotEmpty) {
      final labels = state.selectedStatuses.map(taskStatusLabel).join(", ");
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Status: $labels', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(selectedStatuses: const {})),
        ),
      );
    }

    // Due filter chip
    if (state.dueFilter != DueFilterOption.all) {
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Due: ${state.dueFilter.label}', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(dueFilter: DueFilterOption.all)),
        ),
      );
    }

    // Assignee filter chip
    if (state.selectedAssignees.isNotEmpty || !state.includeUnassigned) {
      final parts = <String>[];
      if (state.selectedAssignees.isNotEmpty) parts.add(state.selectedAssignees.join(", "));
      if (!state.includeUnassigned) parts.add('Assigned only');
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Assignees: ${parts.join(" | ")}', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(selectedAssignees: const {}, includeUnassigned: true)),
        ),
      );
    }

    // Time filter chip
    if (state.timeFilter != TimeFilterOption.all) {
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Time: ${state.timeFilter.label}', style: const TextStyle(fontSize: 12)),
          onDeleted: () => onStateChanged(state.copyWith(timeFilter: TimeFilterOption.all)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Showing $filteredCount of $totalCount tasks:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final chip in chips) ...[
                    chip,
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => onStateChanged(state.resetAll()),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Clear all', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
