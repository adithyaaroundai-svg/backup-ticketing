import '../../core/dev_task_chat_helper.dart';
import '../../core/upload_part.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/advance.dart';
import '../../domain/entities/status_history.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_note.dart';
import '../../domain/entities/user.dart';

class TaskEditProvider extends ChangeNotifier {
  final int taskId;
  TaskEditProvider(this.taskId);

  bool loading = false;
  String? error;

  Task? task;
  List<UserRef> users = [];
  List<Advance> advances = [];
  List<TaskNote> notes = [];
  List<TaskStatusHistoryEntry> statusHistory = [];
  String? today;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final tResp = await supabase.schema('aroundtally').from('tasks').select('''
        *,
        clients ( name ),
        task_assignees ( user_id, users ( name ) ),
        task_files ( * ),
        creator:users!tasks_created_by_fkey ( name ),
        updater:users!tasks_status_updated_by_fkey ( name )
      ''').eq('id', taskId).single();

      final clientObj = tResp['clients'];
      final cName = (clientObj is Map) ? clientObj['name'] : null;

      final assigneesData = tResp['task_assignees'];
      final assignees = [];
      if (assigneesData is List) {
        for (var a in assigneesData) {
          final uObj = a['users'];
          assignees.add({
            'id': a['user_id'],
            'name': (uObj is Map) ? uObj['name'] : null,
          });
        }
      }

      final advancesResp = await supabase.schema('aroundtally').from('advances').select('''
        *, users ( name )
      ''').eq('task_id', taskId).order('created_at', ascending: false);

      num advancesTotal = 0;
      advances = (advancesResp as List).map((row) {
        advancesTotal += (row['amount'] ?? 0);
        final u = row['users'];
        return Advance.fromJson({
          ...row,
          'created_by_name': (u is Map) ? u['name'] : null,
        });
      }).toList();

      final createdUser = tResp['creator'];
      final updatedUser = tResp['updater'];

      final mappedTask = {
        ...tResp,
        'client': cName,
        'assignees': assignees,
        'files': tResp['task_files'] ?? [],
        'advances_total': advancesTotal,
        'created_by_name': (createdUser is Map) ? createdUser['name'] : null,
        'status_updated_by_name': (updatedUser is Map) ? updatedUser['name'] : null,
      };

      task = Task.fromJson(mappedTask);

      final usersResp = await supabase.schema('aroundtally').from('users').select('id, name');
      users = (usersResp as List).map((e) => UserRef.fromJson(Map<String, dynamic>.from(e))).toList();

      final notesResp = await supabase.schema('aroundtally').from('task_notes').select('''
        *, users ( name )
      ''').eq('task_id', taskId).order('created_at', ascending: true);
      
      notes = (notesResp as List).map((row) {
        final u = row['users'];
        return TaskNote.fromJson({
          ...row,
          'created_by_name': (u is Map) ? u['name'] : null,
        });
      }).toList();

      final historyResp = await supabase.schema('aroundtally').from('task_status_history').select('''
        *, users ( name )
      ''').eq('task_id', taskId).order('id', ascending: true);

      statusHistory = (historyResp as List).map((row) {
        final u = row['users'];
        return TaskStatusHistoryEntry.fromJson({
          ...row,
          'changed_by_name': (u is Map) ? u['name'] : null,
        });
      }).toList();

    } catch (e) {
      debugPrint('Error loading task edit: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveFull({
    String? description,
    String? priority,
    String? status,
    bool? approved,
    String? expectedFinish,
    String? billAmount,
    bool? billed,
    String? cancelReason,
    String? statusMessage,
    String? startDate,
    List<int>? assigneeIds,
    List<int> removeFileIds = const [],
    List<UploadPart> newFiles = const [],
    int? currentUserId,
    String? currentUserName,
  }) async {
    final supabase = Supabase.instance.client;
    
    final updates = <String, dynamic>{};
    if (description != null) updates['description'] = description;
    if (priority != null) updates['priority'] = priority;
    if (status != null) updates['status'] = status;
    if (approved != null) updates['approved'] = approved ? 1 : 0;
    if (expectedFinish != null) updates['expected_finish'] = expectedFinish;
    if (billAmount != null) updates['bill_amount'] = num.tryParse(billAmount);
    if (billed != null) updates['billed'] = billed ? 1 : 0;
    if (cancelReason != null) updates['cancel_reason'] = cancelReason;
    if (startDate != null) updates['start_date'] = startDate;
    if (status != null && currentUserId != null) updates['status_updated_by'] = currentUserId;

    if (updates.isNotEmpty) {
      await supabase.schema('aroundtally').from('tasks').update(updates).eq('id', taskId);
    }

    if (statusMessage != null && statusMessage.isNotEmpty) {
      await supabase.schema('aroundtally').from('task_status_history').insert({
        'task_id': taskId,
        'message': statusMessage,
        'user_id': currentUserId,
      });
    }

    if (assigneeIds != null) {
      await supabase.schema('aroundtally').from('task_assignees').delete().eq('task_id', taskId);
      for (final aId in assigneeIds) {
        await supabase.schema('aroundtally').from('task_assignees').insert({
          'task_id': taskId,
          'user_id': aId,
        });
      }
    }

    if (removeFileIds.isNotEmpty) {
      await supabase.schema('aroundtally').from('task_files').delete().inFilter('id', removeFileIds);
    }

    for (final part in newFiles) {
      final path = '${DateTime.now().millisecondsSinceEpoch}_${part.filename}';
      await supabase.storage.from('dev_crm_files').uploadBinary(path, Uint8List.fromList(part.bytes));
      await supabase.schema('aroundtally').from('task_files').insert({
        'task_id': taskId,
        'filename': part.filename,
        'storage_path': path,
      });
    }

    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = task?.description ?? '#$taskId';
        String logMessage = '';
        if (updates.isNotEmpty) {
          if (status != null && task != null && status != task!.status) {
            postDevTaskStatusChangeToSoftwareDevChannel(
              taskId: taskId,
              oldStatus: task!.status,
              newStatus: status,
              taskDescription: description ?? task!.description,
              clientName: task?.client,
              clientId: task!.clientId,
              currentUserId: currentUserId,
              currentUserName: currentUserName,
              statusMessage: statusMessage,
            );
          }

          if (status != null && status == 'completed') {
            logMessage = 'completed task "$tDesc" → added to Work History';
          } else if (status != null && task != null && status != task!.status) {
            logMessage = 'updated task "$tDesc" (status changed to $status)';
          } else {
            logMessage = 'edited task "$tDesc" details';
          }
        }
        if (logMessage.isNotEmpty) {
          await supabase.schema('aroundtally').from('activity_log').insert({
            'user_id': currentUserId,
            'user_name': currentUserName,
            'message': logMessage,
          });
        }
      } catch (e) {
        debugPrint('Error logging save full activity: $e');
      }
    }

    await load();
  }

  Future<void> addNote(String body, {int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').from('task_notes').insert({
      'task_id': taskId,
      'body': body,
      'created_by': currentUserId,
    });
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = task?.description ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'added note "$body" to task "$tDesc"',
        });
      } catch (e) {}
    }
    await load();
  }

  Future<void> addAdvance(num amount, String? note, {int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').from('advances').insert({
      'task_id': taskId,
      'amount': amount,
      'note': note,
      'created_by': currentUserId,
    });
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = task?.description ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'added advance ${amount} to task "$tDesc"',
        });
      } catch (e) {}
    }
    await load();
  }

  Future<void> delete({int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').from('tasks').delete().eq('id', taskId);
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = task?.description ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'deleted task "$tDesc"',
        });
      } catch (e) {}
    }
  }

  Future<void> toPending({int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').from('tasks').update({'pending': 1}).eq('id', taskId);
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = task?.description ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'moved task "$tDesc" into Pending',
        });
      } catch (e) {}
    }
    await load();
  }

  Future<void> activate({int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').from('tasks').update({'pending': 0}).eq('id', taskId);
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = task?.description ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'moved pending task "$tDesc" into Today\'s Tasks',
        });
      } catch (e) {}
    }
    await load();
  }

  Future<void> carryForward({int? currentUserId, String? currentUserName}) async {
    await Supabase.instance.client.schema('aroundtally').rpc('carry_forward_one', params: {'p_task_id': taskId});
    if (currentUserId != null && currentUserName != null) {
      try {
        final tDesc = task?.description ?? '#$taskId';
        await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'carried forward task "$tDesc" into today',
        });
      } catch (e) {}
    }
    await load();
  }
}
