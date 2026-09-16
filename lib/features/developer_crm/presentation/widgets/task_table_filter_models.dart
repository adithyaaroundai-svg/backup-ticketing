import 'package:flutter/foundation.dart';
import '../../domain/entities/task.dart';

enum SortDirection {
  none,
  asc,
  desc;

  SortDirection next() {
    switch (this) {
      case SortDirection.none:
        return SortDirection.asc;
      case SortDirection.asc:
        return SortDirection.desc;
      case SortDirection.desc:
        return SortDirection.none;
    }
  }
}

enum TaskColumn {
  client('Client'),
  description('Description'),
  priority('Priority'),
  status('Status'),
  due('Due'),
  assignees('Assignees'),
  time('Time');

  final String label;
  const TaskColumn(this.label);
}

enum DueFilterOption {
  all('All'),
  hasDate('Has due date'),
  noDate('No due date'),
  overdue('Overdue'),
  today('Due today');

  final String label;
  const DueFilterOption(this.label);
}

enum TimeFilterOption {
  all('All'),
  withTime('Tracked time (> 0)'),
  noTime('No time (0:00)');

  final String label;
  const TimeFilterOption(this.label);
}

@immutable
class TaskTableFilterState {
  final TaskColumn? sortColumn;
  final SortDirection sortDirection;

  // Filters
  final String clientSearch;
  final Set<String> selectedClients;
  final String descriptionSearch;
  final Set<String> selectedPriorities;
  final Set<String> selectedStatuses;
  final DueFilterOption dueFilter;
  final Set<String> selectedAssignees;
  final bool includeUnassigned;
  final TimeFilterOption timeFilter;

  const TaskTableFilterState({
    this.sortColumn,
    this.sortDirection = SortDirection.none,
    this.clientSearch = '',
    this.selectedClients = const {},
    this.descriptionSearch = '',
    this.selectedPriorities = const {},
    this.selectedStatuses = const {},
    this.dueFilter = DueFilterOption.all,
    this.selectedAssignees = const {},
    this.includeUnassigned = true,
    this.timeFilter = TimeFilterOption.all,
  });

  bool get hasActiveSort => sortColumn != null && sortDirection != SortDirection.none;

  bool isColumnSorted(TaskColumn col) => sortColumn == col && sortDirection != SortDirection.none;

  bool isColumnFiltered(TaskColumn col) {
    switch (col) {
      case TaskColumn.client:
        return clientSearch.trim().isNotEmpty || selectedClients.isNotEmpty;
      case TaskColumn.description:
        return descriptionSearch.trim().isNotEmpty;
      case TaskColumn.priority:
        return selectedPriorities.isNotEmpty;
      case TaskColumn.status:
        return selectedStatuses.isNotEmpty;
      case TaskColumn.due:
        return dueFilter != DueFilterOption.all;
      case TaskColumn.assignees:
        return selectedAssignees.isNotEmpty || !includeUnassigned;
      case TaskColumn.time:
        return timeFilter != TimeFilterOption.all;
    }
  }

  bool get hasActiveFilters {
    return isColumnFiltered(TaskColumn.client) ||
        isColumnFiltered(TaskColumn.description) ||
        isColumnFiltered(TaskColumn.priority) ||
        isColumnFiltered(TaskColumn.status) ||
        isColumnFiltered(TaskColumn.due) ||
        isColumnFiltered(TaskColumn.assignees) ||
        isColumnFiltered(TaskColumn.time);
  }

  int get activeFilterCount {
    int count = 0;
    for (final col in TaskColumn.values) {
      if (isColumnFiltered(col)) count++;
    }
    return count;
  }

  TaskTableFilterState copyWith({
    TaskColumn? Function()? sortColumn,
    SortDirection? sortDirection,
    String? clientSearch,
    Set<String>? selectedClients,
    String? descriptionSearch,
    Set<String>? selectedPriorities,
    Set<String>? selectedStatuses,
    DueFilterOption? dueFilter,
    Set<String>? selectedAssignees,
    bool? includeUnassigned,
    TimeFilterOption? timeFilter,
  }) {
    return TaskTableFilterState(
      sortColumn: sortColumn != null ? sortColumn() : this.sortColumn,
      sortDirection: sortDirection ?? this.sortDirection,
      clientSearch: clientSearch ?? this.clientSearch,
      selectedClients: selectedClients ?? this.selectedClients,
      descriptionSearch: descriptionSearch ?? this.descriptionSearch,
      selectedPriorities: selectedPriorities ?? this.selectedPriorities,
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      dueFilter: dueFilter ?? this.dueFilter,
      selectedAssignees: selectedAssignees ?? this.selectedAssignees,
      includeUnassigned: includeUnassigned ?? this.includeUnassigned,
      timeFilter: timeFilter ?? this.timeFilter,
    );
  }

  TaskTableFilterState toggleSort(TaskColumn col) {
    if (sortColumn != col) {
      return copyWith(
        sortColumn: () => col,
        sortDirection: SortDirection.asc,
      );
    }
    final next = sortDirection.next();
    if (next == SortDirection.none) {
      return copyWith(
        sortColumn: () => null,
        sortDirection: SortDirection.none,
      );
    }
    return copyWith(
      sortColumn: () => col,
      sortDirection: next,
    );
  }

  TaskTableFilterState clearColumnFilter(TaskColumn col) {
    switch (col) {
      case TaskColumn.client:
        return copyWith(clientSearch: '', selectedClients: const {});
      case TaskColumn.description:
        return copyWith(descriptionSearch: '');
      case TaskColumn.priority:
        return copyWith(selectedPriorities: const {});
      case TaskColumn.status:
        return copyWith(selectedStatuses: const {});
      case TaskColumn.due:
        return copyWith(dueFilter: DueFilterOption.all);
      case TaskColumn.assignees:
        return copyWith(selectedAssignees: const {}, includeUnassigned: true);
      case TaskColumn.time:
        return copyWith(timeFilter: TimeFilterOption.all);
    }
  }

  TaskTableFilterState clearAllFilters() {
    return copyWith(
      clientSearch: '',
      selectedClients: const {},
      descriptionSearch: '',
      selectedPriorities: const {},
      selectedStatuses: const {},
      dueFilter: DueFilterOption.all,
      selectedAssignees: const {},
      includeUnassigned: true,
      timeFilter: TimeFilterOption.all,
    );
  }

  TaskTableFilterState resetAll() {
    return const TaskTableFilterState();
  }

  /// Priority ranking: A+ (1), A (2), B (3), others (4)
  static int _priorityRank(String p) {
    final up = p.trim().toUpperCase();
    if (up == 'A+') return 1;
    if (up == 'A') return 2;
    if (up == 'B') return 3;
    return 4;
  }

  /// Status rank according to typical workflow order
  static int _statusRank(String s) {
    switch (s) {
      case 'not_started':
        return 1;
      case 'working':
        return 2;
      case 'ready_for_testing':
        return 3;
      case 'ready_for_implementation':
        return 4;
      case 'awaiting_confirmation':
        return 5;
      case 'completed':
        return 6;
      case 'paused':
        return 7;
      case 'cancelled':
        return 8;
      default:
        return 99;
    }
  }

  List<Task> apply(List<Task> originalTasks) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Filtering
    final filtered = originalTasks.where((t) {
      // Client filter
      if (clientSearch.trim().isNotEmpty) {
        final c = (t.client ?? '').toLowerCase();
        if (!c.contains(clientSearch.trim().toLowerCase())) return false;
      }
      if (selectedClients.isNotEmpty) {
        final c = t.client ?? '';
        if (!selectedClients.contains(c)) return false;
      }

      // Description filter
      if (descriptionSearch.trim().isNotEmpty) {
        if (!t.description.toLowerCase().contains(descriptionSearch.trim().toLowerCase())) {
          return false;
        }
      }

      // Priority filter
      if (selectedPriorities.isNotEmpty) {
        if (!selectedPriorities.contains(t.priority)) return false;
      }

      // Status filter
      if (selectedStatuses.isNotEmpty) {
        if (!selectedStatuses.contains(t.status)) return false;
      }

      // Due filter
      if (dueFilter != DueFilterOption.all) {
        final finish = t.expectedFinish?.trim();
        switch (dueFilter) {
          case DueFilterOption.hasDate:
            if (finish == null || finish.isEmpty) return false;
            break;
          case DueFilterOption.noDate:
            if (finish != null && finish.isNotEmpty) return false;
            break;
          case DueFilterOption.overdue:
            if (finish == null || finish.isEmpty) return false;
            final dt = DateTime.tryParse(finish);
            if (dt == null || !dt.isBefore(DateTime(now.year, now.month, now.day))) {
              return false;
            }
            break;
          case DueFilterOption.today:
            if (finish == null || finish.isEmpty) return false;
            if (!finish.startsWith(todayStr)) return false;
            break;
          case DueFilterOption.all:
            break;
        }
      }

      // Assignees filter
      if (selectedAssignees.isNotEmpty || !includeUnassigned) {
        final assigneeNames = t.assignees.map((a) => a.name ?? '#${a.id}').toSet();
        if (assigneeNames.isEmpty) {
          if (!includeUnassigned) return false;
        } else {
          if (selectedAssignees.isNotEmpty && !assigneeNames.any((name) => selectedAssignees.contains(name))) {
            return false;
          }
        }
      }

      // Time filter
      if (timeFilter != TimeFilterOption.all) {
        final seconds = t.liveSeconds();
        if (timeFilter == TimeFilterOption.withTime && seconds <= 0) return false;
        if (timeFilter == TimeFilterOption.noTime && seconds > 0) return false;
      }

      return true;
    }).toList();

    // 2. Sorting
    if (sortColumn == null || sortDirection == SortDirection.none) {
      return filtered;
    }

    final isAsc = sortDirection == SortDirection.asc;

    filtered.sort((a, b) {
      int cmp = 0;
      switch (sortColumn!) {
        case TaskColumn.client:
          final aClient = (a.client ?? '').toLowerCase();
          final bClient = (b.client ?? '').toLowerCase();
          cmp = aClient.compareTo(bClient);
          break;

        case TaskColumn.description:
          cmp = a.description.toLowerCase().compareTo(b.description.toLowerCase());
          break;

        case TaskColumn.priority:
          final aRank = _priorityRank(a.priority);
          final bRank = _priorityRank(b.priority);
          cmp = aRank.compareTo(bRank);
          break;

        case TaskColumn.status:
          final aRank = _statusRank(a.status);
          final bRank = _statusRank(b.status);
          cmp = aRank.compareTo(bRank);
          break;

        case TaskColumn.due:
          final aFinish = a.expectedFinish;
          final bFinish = b.expectedFinish;
          if (aFinish == null && bFinish == null) {
            cmp = 0;
          } else if (aFinish == null) {
            return 1; // Put nulls at the end regardless of sort direction
          } else if (bFinish == null) {
            return -1;
          } else {
            cmp = aFinish.compareTo(bFinish);
          }
          break;

        case TaskColumn.assignees:
          final aAssignees = a.assignees.map((u) => u.name ?? '').join(', ').toLowerCase();
          final bAssignees = b.assignees.map((u) => u.name ?? '').join(', ').toLowerCase();
          if (aAssignees.isEmpty && bAssignees.isNotEmpty) {
            return 1;
          } else if (aAssignees.isNotEmpty && bAssignees.isEmpty) {
            return -1;
          } else {
            cmp = aAssignees.compareTo(bAssignees);
          }
          break;

        case TaskColumn.time:
          final aSec = a.liveSeconds();
          final bSec = b.liveSeconds();
          cmp = aSec.compareTo(bSec);
          break;
      }

      return isAsc ? cmp : -cmp;
    });

    return filtered;
  }
}
