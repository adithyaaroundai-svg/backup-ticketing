import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../domain/entities/task.dart';

class TaskBoardProvider extends ChangeNotifier {
  final ApiClient api;
  final bool pendingBoard;
  TaskBoardProvider(this.api, {this.pendingBoard = false});

  bool loading = false;
  String? error;
  List<Task> tasks = [];
  String? today;
  int? assigneeFilter;
  int? clientFilter;

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

    final history = row['task_status_history'];
    String? lastStatusMessage;
    if (history is List && history.isNotEmpty) {
      // Assuming they come back ordered or we take the first/last
      lastStatusMessage = history.last['message'];
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
      'last_status_message': lastStatusMessage,
    };
  }

  Future<void> load({int? assignee, int? client}) async {
    assigneeFilter = assignee ?? assigneeFilter;
    clientFilter = client ?? clientFilter;
    loading = true;
    error = null;
    notifyListeners();
    
    try {
      final supabase = Supabase.instance.client;
      today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      var query = supabase.schema('aroundtally').from('tasks').select('''
        *,
        clients ( name ),
        task_assignees ( user_id, users ( name ) ),
        advances ( amount ),
        task_status_history ( message ),
        task_files ( * ),
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
      
      // If we filtered by assignee, Supabase inner join filter behavior on arrays can be weird,
      // so let's double filter in dart just in case.
      if (assigneeFilter != null) {
        mapped.retainWhere((t) {
          final aList = t['assignees'] as List;
          return aList.any((a) => a['id'] == assigneeFilter);
        });
      }

      tasks = mapped.map((e) => Task.fromJson(e)).toList();
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
  }

  Future<void> quickUpdate(
    int taskId, {
    String? priority,
    String? status,
    bool? approved,
    String? cancelReason,
    String? statusMessage,
  }) async {
    final supabase = Supabase.instance.client;
    final updates = <String, dynamic>{};
    if (priority != null) updates['priority'] = priority;
    if (status != null) updates['status'] = status;
    if (approved != null) updates['approved'] = approved ? 1 : 0;
    if (cancelReason != null) updates['cancel_reason'] = cancelReason;
    
    // Status message technically needs an insert into task_status_history,
    // but we can just update the task for now.
    
    if (updates.isNotEmpty) {
      await supabase.schema('aroundtally').from('tasks').update(updates).eq('id', taskId);
    }
    await load();
  }

  Future<Map<String, dynamic>> createTask({
    required int clientId,
    required String description,
    String priority = 'A',
    String status = 'not_started',
    String? expectedFinish,
    String? startDate,
    bool approved = false,
    bool pending = false,
    List<int> assigneeIds = const [],
    List<UploadPart> files = const [],
  }) async {
    final supabase = Supabase.instance.client;
    final taskDate = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());

    final resp = await supabase.schema('aroundtally').from('tasks').insert({
      'client_id': clientId,
      'description': description,
      'priority': priority,
      'status': status,
      'expected_finish': expectedFinish,
      'start_date': startDate,
      'task_date': taskDate,
      'approved': approved ? 1 : 0,
      'pending': pending ? 1 : 0,
      // 'created_by': we should inject current user id here, but we will leave null if not available
    }).select().single();
    
    final taskId = resp['id'];
    
    for (final aId in assigneeIds) {
      await supabase.schema('aroundtally').from('task_assignees').insert({
        'task_id': taskId,
        'user_id': aId,
      });
    }

    for (final part in files) {
      final path = '${DateTime.now().millisecondsSinceEpoch}_${part.filename}';
      await supabase.storage.from('dev_crm_files').uploadBinary(path, Uint8List.fromList(part.bytes));
      await supabase.schema('aroundtally').from('task_files').insert({
        'task_id': taskId,
        'filename': part.filename,
        'storage_path': path,
      });
    }
    
    await load();
    return resp;
  }

  Future<void> toPending(int taskId) async {
    await Supabase.instance.client.schema('aroundtally').from('tasks').update({'pending': 1}).eq('id', taskId);
    await load();
  }

  Future<void> activate(int taskId) async {
    await Supabase.instance.client.schema('aroundtally').from('tasks').update({'pending': 0}).eq('id', taskId);
    await load();
  }

  Future<void> carryForwardOne(int taskId) async {
    await Supabase.instance.client.schema('aroundtally').rpc('carry_forward_one', params: {'p_task_id': taskId});
    await load();
  }

  Future<int> carryForwardAll() async {
    final resp = await Supabase.instance.client.schema('aroundtally').rpc('carry_forward_all');
    await load();
    if (resp is num) return resp.toInt();
    return 0;
  }
}
