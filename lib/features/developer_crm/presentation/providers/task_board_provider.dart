import 'dart:async';
import '../../core/crm_storage_service.dart';
import '../../core/dev_task_chat_helper.dart';
import '../../core/time_utils.dart';
import '../../core/upload_part.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task.dart';

class PendingBoardProvider extends TaskBoardProvider {
  PendingBoardProvider() : super(pendingBoard: true);
}

class TaskBoardProvider extends ChangeNotifier {
  final bool pendingBoard;
  TaskBoardProvider({this.pendingBoard = false});

  bool loading = false;
  String? error;
  List<Task> tasks = [];
  String? today;
  int? assigneeFilter;
  int? clientFilter;
  String statusFilter = 'active'; // 'active', 'completed', 'cancelled'

  List<Task> get filteredTasks {
    return tasks.where((t) {
      final s = t.status.trim().toLowerCase();
      if (statusFilter == 'completed') {
        return s == 'completed';
      } else if (statusFilter == 'cancelled') {
        return s == 'cancelled';
      } else if (statusFilter == 'active') {
        return s != 'completed' && s != 'cancelled';
      }
      return true;
    }).toList();
  }

  int get activeTasksCount => tasks.where((t) {
    final s = t.status.trim().toLowerCase();
    return s != 'completed' && s != 'cancelled';
  }).length;

  int get completedTasksCount => tasks.where((t) {
    final s = t.status.trim().toLowerCase();
    return s == 'completed';
  }).length;

  int get cancelledTasksCount => tasks.where((t) {
    final s = t.status.trim().toLowerCase();
    return s == 'cancelled';
  }).length;

  void setStatusFilter(String filter) {
    statusFilter = filter;
    notifyListeners();
  }

  // Map Supabase row to legacy JSON shape
  Map<String, dynamic> _mapSupabaseToLegacy(Map<String, dynamic> row) {
    final clientObj = row['clients'];
    final clientName = (clientObj is Map) ? clientObj['name'] : null;

    final assigneesData = row['task_assignees'];
    final assignees = [];
    if (assigneesData is List) {
      for (var a in assigneesData) {
        final userObj = a['users'];
        assignees.add({
          'id': a['user_id'],
          'name': (userObj is Map) ? userObj['name'] : null,
        });
      }
    }

    final advancesData = row['advances'];
    num advancesTotal = 0;
    if (advancesData is List) {
      for (var adv in advancesData) {
        advancesTotal += (adv['amount'] ?? 0);
      }
    }
    
    final createdUser = row['creator'];
    final updatedUser = row['updater'];

    return {
      ...row,
      'client': clientName,
      'assignees': assignees,
      'files': row['task_files'] ?? [],
      'advances_total': advancesTotal,
      'created_by_name': (createdUser is Map) ? createdUser['name'] : null,
      'status_updated_by_name': (updatedUser is Map) ? updatedUser['name'] : null,
      'last_status_message': null,
    };
  }

  Future<void> setAssigneeFilter(int? assignee) async {
    assigneeFilter = assignee;
    await load();
  }

  Future<void> setClientFilter(int? client) async {
    clientFilter = client;
    await load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent || tasks.isEmpty) {
      loading = true;
      error = null;
      notifyListeners();
    }
    
    try {
      final supabase = Supabase.instance.client;
      final todayIst = todayIstDateKey();
      today = todayIst;

      var query = supabase.schema('aroundtally').from('tasks').select('''
        id,
        description,
        priority,
        status,
        expected_finish,
        start_date,
        task_date,
        pending,
        approved,
        client_id,
        created_by,
        status_updated_by,
        status_updated_at,
        cancel_reason,
        time_spent_seconds,
        timer_started_at,
        created_at,
        completed_at,
        display_date,
        clients ( name ),
        task_assignees ( user_id, users ( name ) ),
        advances ( amount ),
        creator:users!tasks_created_by_fkey ( name ),
        updater:users!tasks_status_updated_by_fkey ( name )
      ''');

      if (pendingBoard) {
        query = query.eq('pending', 1);
      } else {
        query = query.eq('pending', 0);
      }

      if (assigneeFilter != null) {
        query = query.eq('task_assignees.user_id', assigneeFilter!);
      }

      if (!pendingBoard && clientFilter != null) {
        query = query.eq('client_id', clientFilter!);
      }

      final response = await query.order('id', ascending: false);
      
      final mapped = (response as List).map((row) => _mapSupabaseToLegacy(row)).toList();

      if (assigneeFilter != null) {
        mapped.retainWhere((t) {
          final aList = t['assignees'] as List;
          return aList.any((a) => a['id'] == assigneeFilter);
        });
      }

      var loaded = mapped.map((e) => Task.fromJson(e)).toList();
      if (!pendingBoard) {
        loaded = await _autoCarryForwardYetToStart(loaded, todayIst);
      }
      tasks = loaded;
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearFilters() {
    assigneeFilter = null;
    clientFilter = null;
    statusFilter = 'active';
    notifyListeners();
  }

  Future<void> quickUpdate(
    int taskId, {
    String? priority,
    String? status,
    bool? approved,
    String? cancelReason,
    String? statusMessage,
    String? taskDescription,
    int? currentUserId,
    String? currentUserName,
  }) async {
    // 1. Instant optimistic update in local state for 0ms lag
    final idx = tasks.indexWhere((t) => t.id == taskId);
    final oldTask = (idx != -1) ? tasks[idx] : null;
    if (idx != -1 && oldTask != null) {
      tasks[idx] = oldTask.copyWith(
        description: taskDescription,
        priority: priority,
        status: status,
        approved: approved,
        cancelReason: cancelReason,
        lastStatusMessage: statusMessage,
        statusUpdatedByName: currentUserName,
      );
      notifyListeners();
    }

    final supabase = Supabase.instance.client;
    final updates = <String, dynamic>{};
    if (priority != null) updates['priority'] = priority;
    if (status != null) updates['status'] = status;
    if (approved != null) updates['approved'] = approved ? 1 : 0;
    if (cancelReason != null) updates['cancel_reason'] = cancelReason;
    
    if (status != null && currentUserId != null) {
      updates['status_updated_by'] = currentUserId;
      updates['status_updated_at'] = DateTime.now().toIso8601String();
    }

    if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }
    
    if (updates.isNotEmpty) {
      await supabase.schema('aroundtally').from('tasks').update(updates).eq('id', taskId);
      if (status != null && (oldTask == null || oldTask.status != status)) {
        unawaited(postDevTaskStatusChangeToSoftwareDevChannel(
          taskId: taskId,
          oldStatus: oldTask?.status,
          newStatus: status,
          taskDescription: oldTask?.description ?? taskDescription,
          clientName: oldTask?.client,
          clientId: oldTask?.clientId,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          statusMessage: statusMessage,
        ));
      }
    }
    
    // Status message insert into task_status_history in background
    if (statusMessage != null && statusMessage.isNotEmpty && currentUserId != null) {
      unawaited(() async {
        try {
          await supabase.schema('aroundtally').from('task_status_history').insert({
            'task_id': taskId,
            'message': statusMessage,
            'user_id': currentUserId,
          });
        } catch (e) {
          debugPrint('Error inserting task status history: $e');
        }
      }());
    }

    if (currentUserId != null && currentUserName != null) {
      unawaited(() async {
        try {
          String logMessage = '';
          final tDesc = taskDescription ?? '#$taskId';
          if (status != null) {
            logMessage = 'updated task "$tDesc" (status changed to $status)';
          } else if (priority != null) {
            logMessage = 'updated task "$tDesc" (priority $priority)';
          } else if (approved != null) {
            logMessage = 'updated task "$tDesc" (${approved ? "approved" : "un-approved"})';
          }
          
          if (logMessage.isNotEmpty) {
            await supabase.schema('aroundtally').from('activity_log').insert({
              'user_id': currentUserId,
              'user_name': currentUserName,
              'message': logMessage,
            });
          }
          
          if (status == 'completed') {
            await supabase.schema('aroundtally').from('activity_log').insert({
              'user_id': currentUserId,
              'user_name': currentUserName,
              'message': 'completed task "$tDesc" → added to Work History',
            });
          }
        } catch (_) {}
      }());
    } 

    await load();
  }

  Future<Map<String, dynamic>> createTask({
    required int clientId,
    String? clientName,
    required String description,
    String priority = 'A',
    String status = 'not_started',
    String? expectedFinish,
    String? startDate,
    bool approved = false,
    bool pending = false,
    List<int> assigneeIds = const [],
    List<UploadPart> files = const [],
    int? currentUserId,
    String? currentUserName,
  }) async {
    final supabase = Supabase.instance.client;
    final taskDate = todayIstDateKey();

    final resp = await supabase.schema('aroundtally').from('tasks').insert({
      'client_id': clientId,
      'description': description,
      'priority': priority,
      'status': status,
      'expected_finish': expectedFinish,
      'start_date': startDate,
      'task_date': taskDate,
      'display_date': taskDate,
      'approved': approved ? 1 : 0,
      'pending': pending ? 1 : 0,
      'created_by': currentUserId,
    }).select().single();
    
    final taskId = resp['id'];

    if (currentUserId != null && currentUserName != null) {
      final taskType = pending ? 'pending task' : 'today\'s task';
      final cName = clientName ?? 'Client #$clientId';
      try {
        await supabase.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'added $taskType "$description" for $cName',
        });
      } catch (e) {
        debugPrint('Error logging activity: $e');
      }
    }
    
    for (final aId in assigneeIds) {
      await supabase.schema('aroundtally').from('task_assignees').insert({
        'task_id': taskId,
        'user_id': aId,
      });
    }

    for (final part in files) {
      final path = await CrmStorageService.uploadFile(part);

      await supabase.schema('aroundtally').from('task_files').insert({
        'task_id': taskId,
        'filename': part.filename,
        'storage_path': path,
      });
    }
    
    await load();
    return resp;
  }

  Future<void> toPending(int taskId, {String? taskDescription, int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').from('tasks').update({'pending': 1}).eq('id', taskId);
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = taskDescription ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'moved task "$tDesc" into Pending',
        });
      } catch (e) {}
    }
    await load();
  }

  Future<void> activate(int taskId, {String? taskDescription, int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').from('tasks').update({'pending': 0}).eq('id', taskId);
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = taskDescription ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'moved pending task "$tDesc" into Today\'s Tasks',
        });
      } catch (e) {}
    }
    await load();
  }

  Future<List<Task>> _autoCarryForwardYetToStart(
    List<Task> loaded,
    String todayIst,
  ) async {
    final staleIds = loaded
        .where((t) => shouldAutoCarryForwardNotStarted(
              status: t.status,
              pending: t.pending,
              displayDate: t.displayDate,
              taskDate: t.taskDate,
              createdAt: t.createdAt,
              todayIst: todayIst,
            ))
        .map((t) => t.id)
        .toList();
    if (staleIds.isEmpty) return loaded;

    try {
      final resp = await Supabase.instance.client
          .schema('aroundtally')
          .from('tasks')
          .update({
            'task_date': todayIst,
            'display_date': todayIst,
          })
          .inFilter('id', staleIds)
          .eq('pending', 0)
          .eq('status', 'not_started')
          .select('id');

      final updatedIds = (resp as List)
          .map((row) => row['id'])
          .whereType<num>()
          .map((n) => n.toInt())
          .toSet();
      if (updatedIds.isEmpty) return loaded;

      return loaded
          .map((t) => updatedIds.contains(t.id)
              ? t.copyWith(taskDate: todayIst, displayDate: todayIst)
              : t)
          .toList();
    } catch (e) {
      debugPrint('Error auto-carrying forward yet-to-start tasks: $e');
      return loaded;
    }
  }

  Future<void> carryForwardOne(int taskId, {String? taskDescription, int? currentUserId, String? currentUserName}) async {
    final today = todayIstDateKey();
    await Supabase.instance.client.schema('aroundtally').rpc('carry_forward_one', params: {'p_task_id': taskId});
    // Keep both task_date and display_date synchronized to today's IST date.
    await Supabase.instance.client
        .schema('aroundtally')
        .from('tasks')
        .update({'display_date': today, 'task_date': today})
        .eq('id', taskId);
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = taskDescription ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'carried forward task "$tDesc" into today',
        });
      } catch (e) {}
    }
    await load();
  }

  Future<int> carryForwardAll({int? currentUserId, String? currentUserName}) async {
    final supabase = Supabase.instance.client;
    final todayIst = todayIstDateKey();

    final nullDisplayIds = tasks
        .where((t) =>
            !t.pending &&
            t.status != 'completed' &&
            t.status != 'cancelled' &&
            (t.displayDate == null || t.displayDate!.isEmpty) &&
            isTaskDateBeforeToday(
              displayDate: t.displayDate,
              taskDate: t.taskDate,
              createdAt: t.createdAt,
              todayIst: todayIst,
            ))
        .map((t) => t.id)
        .toList();

    final resp = await supabase.schema('aroundtally').rpc('carry_forward_all');
    var count = (resp is num) ? resp.toInt() : 0;

    // Ensure display_date (not just task_date) moves to todayIst for unfinished tasks.
    final updatedByDisplay = await supabase
        .schema('aroundtally')
        .from('tasks')
        .update({'task_date': todayIst, 'display_date': todayIst})
        .eq('pending', 0)
        .neq('status', 'completed')
        .neq('status', 'cancelled')
        .lt('display_date', todayIst)
        .select('id');
    final displayUpdatedCount = (updatedByDisplay as List).length;
    if (displayUpdatedCount > count) count = displayUpdatedCount;

    if (nullDisplayIds.isNotEmpty) {
      final updatedNulls = await supabase
          .schema('aroundtally')
          .from('tasks')
          .update({'task_date': todayIst, 'display_date': todayIst})
          .inFilter('id', nullDisplayIds)
          .eq('pending', 0)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .select('id');
      final nullUpdatedCount = (updatedNulls as List).length;
      if (nullUpdatedCount > count) count = nullUpdatedCount;
    }

    await load();
    if (count > 0 && currentUserId != null && currentUserName != null) {
      try {
        await supabase.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'carried forward $count unfinished tasks into today',
        });
      } catch (e) {}
    }
    return count;
  }
}
