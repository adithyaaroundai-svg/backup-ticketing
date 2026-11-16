import '../../core/crm_storage_service.dart';
import '../../core/time_utils.dart';
import '../../core/upload_part.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/client.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/work_item.dart';

class ClientDetailProvider extends ChangeNotifier {
  final int clientId;
  ClientDetailProvider(this.clientId);

  bool loading = false;
  String? error;

  Client? customer;
  String tab = 'tasks';
  List<Task> tasks = [];
  List<Task> pendingTasks = [];
  List<WorkItem> workItems = [];
  List<UserRef> users = [];
  String? today;
  int? filterAssignee;

  Map<String, dynamic> _mapTask(Map<String, dynamic> row, String cName) {
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
      lastStatusMessage = history.last['message'];
    }

    return {
      ...row,
      'client': cName,
      'assignees': assignees,
      'files': row['task_files'] ?? [],
      'advances_total': advancesTotal,
      'last_status_message': lastStatusMessage,
    };
  }

  Future<void> load({String? tab, int? assignee}) async {
    loading = true;
    error = null;
    if (tab != null) this.tab = tab;
    filterAssignee = assignee ?? filterAssignee;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      today = todayIstDateKey();

      final clientResp = await supabase.schema('aroundtally').from('clients').select('*').eq('id', clientId).single();
      customer = Client.fromJson(clientResp);
      final cName = customer!.name;

      final usersResp = await supabase.schema('aroundtally').from('users').select('id, name');
      users = (usersResp as List).map((e) => UserRef.fromJson(Map<String, dynamic>.from(e))).toList();

      if (this.tab == 'tasks' || this.tab == 'pending') {
        var query = supabase.schema('aroundtally').from('tasks').select('''
          *,
          task_assignees ( user_id, users ( name ) ),
          advances ( amount ),
          task_status_history ( message ),
          task_files ( * )
        ''').eq('client_id', clientId);
        
        if (filterAssignee != null) {
          query = query.eq('task_assignees.user_id', filterAssignee!);
        }

        final tasksData = await query.order('id', ascending: false);
        
        final tList = <Task>[];
        final pList = <Task>[];

        for (var row in tasksData as List) {
          final mapped = _mapTask(row, cName);
          
          if (filterAssignee != null) {
            final aList = mapped['assignees'] as List;
            if (!aList.any((a) => a['id'] == filterAssignee)) continue;
          }
          
          final t = Task.fromJson(mapped);
          if (t.pending) {
            pList.add(t);
          } else {
            tList.add(t);
          }
        }
        tasks = tList;
        pendingTasks = pList;
      } else if (this.tab == 'workItems') {
        final wResp = await supabase.schema('aroundtally').from('work_items').select('''
          *,
          work_item_files ( * ),
          work_item_code ( * ),
          projects ( name ),
          author:users!work_items_author_id_fkey ( name )
        ''').eq('client_id', clientId).order('id', ascending: false);
        
        workItems = (wResp as List).map((row) {
          final p = row['projects'];
          final a = row['author'];
          return WorkItem.fromJson({
            ...row,
            'client_name': cName,
            'project_name': (p is Map) ? p['name'] : null,
            'author_name': (a is Map) ? a['name'] : null,
            'files': row['work_item_files'] ?? [],
            'code_blocks': row['work_item_code'] ?? [],
          });
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading client details: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setTab(String newTab) => load(tab: newTab, assignee: filterAssignee);
  Future<void> setAssigneeFilter(int? userId) => load(tab: tab, assignee: userId);

  Future<Map<String, dynamic>> createTask({
    required String description,
    String priority = 'A',
    String status = 'not_started',
    String? expectedFinish,
    String? startDate,
    bool approved = false,
    bool pending = false,
    List<int> assigneeIds = const [],
    List<UploadPart> files = const [],
    CrmBatchUploadProgress? onUploadProgress,
    int? currentUserId,
    String? currentUserName,
  }) async {
    final supabase = Supabase.instance.client;
    final taskDate = todayIstDateKey();

    final uploadedPaths = await CrmStorageService.uploadBatch(
      files,
      onProgress: onUploadProgress,
    );

    late final Map<String, dynamic> resp;
    try {
      resp = await supabase.schema('aroundtally').from('tasks').insert({
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

      for (final aId in assigneeIds) {
        await supabase.schema('aroundtally').from('task_assignees').insert({
          'task_id': taskId,
          'user_id': aId,
        });
      }

      for (var i = 0; i < files.length; i++) {
        await supabase.schema('aroundtally').from('task_files').insert({
          'task_id': taskId,
          'filename': files[i].filename,
          'storage_path': uploadedPaths[i],
        });
      }
    } catch (_) {
      await CrmStorageService.deleteFiles(uploadedPaths);
      rethrow;
    }

    if (currentUserId != null && currentUserName != null) {
      final taskType = pending ? 'pending task' : 'today\'s task';
      final cName = customer?.name ?? 'Client #$clientId';
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

    await load(tab: tab, assignee: filterAssignee);
    return resp;
  }

  Future<int> addWorkItem({
    required String title,
    String? description,
    String? language,
    String? codeSnippet,
    UploadPart? codeFile,
    List<UploadPart> tcpFileParts = const [],
    List<String> tcpComments = const [],
    List<UploadPart> excelFiles = const [],
    List<UploadPart> proposalFiles = const [],
    List<UploadPart> otherFiles = const [],
    CrmBatchUploadProgress? onUploadProgress,
  }) async {
    final supabase = Supabase.instance.client;

    final allParts = <UploadPart>[];
    final categories = <UploadPart, String>{};
    final comments = <UploadPart, String>{};

    for (var i = 0; i < tcpFileParts.length; i++) {
      allParts.add(tcpFileParts[i]);
      categories[tcpFileParts[i]] = 'tcp';
      comments[tcpFileParts[i]] = (i < tcpComments.length) ? tcpComments[i] : '';
    }
    for (final f in excelFiles) {
      allParts.add(f);
      categories[f] = 'excel';
    }
    for (final f in proposalFiles) {
      allParts.add(f);
      categories[f] = 'proposal';
    }
    for (final f in otherFiles) {
      allParts.add(f);
      categories[f] = 'other';
    }
    if (codeFile != null) {
      allParts.add(codeFile);
      categories[codeFile] = 'other'; // No explicit category for code_file in schema? Or 'other'
    }

    final uploadedPaths = await CrmStorageService.uploadBatch(
      allParts,
      onProgress: onUploadProgress,
    );

    late final int wId;
    try {
      final resp = await supabase.schema('aroundtally').from('work_items').insert({
        'client_id': clientId,
        'title': title,
        'description': description,
      }).select().single();

      wId = resp['id'] as int;

      if (codeSnippet != null && codeSnippet.isNotEmpty) {
        await supabase.schema('aroundtally').from('work_item_code').insert({
          'work_item_id': wId,
          'language': language ?? 'text',
          'code': codeSnippet,
        });
      }

      for (var i = 0; i < allParts.length; i++) {
        final part = allParts[i];
        await supabase.schema('aroundtally').from('work_item_files').insert({
          'work_item_id': wId,
          'filename': part.filename,
          'storage_path': uploadedPaths[i],
          'category': categories[part] ?? 'other',
          'comment': comments[part],
        });
      }
    } catch (_) {
      await CrmStorageService.deleteFiles(uploadedPaths);
      rethrow;
    }

    await load(tab: tab, assignee: filterAssignee);
    return wId;
  }

  Future<void> deleteWorkItem(int id) async {
    final supabase = Supabase.instance.client;
    final storagePaths = <String>[];
    try {
      final rows = await supabase
          .schema('aroundtally')
          .from('work_item_files')
          .select('storage_path')
          .eq('work_item_id', id);
      for (final row in rows as List) {
        final p = row['storage_path']?.toString();
        if (p != null && p.isNotEmpty) storagePaths.add(p);
      }
    } catch (e) {
      debugPrint('Error reading work item file paths before delete: $e');
    }

    await supabase.schema('aroundtally').from('work_items').delete().eq('id', id);
    await CrmStorageService.deleteFiles(storagePaths);
    await load(tab: tab, assignee: filterAssignee);
  }

  Future<List<RevealedCodeBlock>> revealCode(int workItemId, String password) async {
    // For now, bypass password check and just return the code
    final resp = await Supabase.instance.client.schema('aroundtally').from('work_item_code').select('*').eq('work_item_id', workItemId);
    return (resp as List).map((e) => RevealedCodeBlock.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> updateClientDetails({
    required String name,
    String? contact,
    int? currentUserId,
    String? currentUserName,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final cleanName = name.trim();
      final cleanContact = (contact != null && contact.trim().isNotEmpty) ? contact.trim() : null;

      final resp = await supabase.schema('aroundtally').from('clients').update({
        'name': cleanName,
        'contact': cleanContact,
      }).eq('id', clientId).select().single();

      customer = Client.fromJson({
        ...resp,
        if (customer != null) ...{
          'open_count': customer!.openCount,
          'ongoing': customer!.ongoing,
          'last_activity': customer!.lastActivity,
        }
      });

      if (currentUserId != null && currentUserName != null) {
        try {
          await supabase.schema('aroundtally').from('activity_log').insert({
            'user_id': currentUserId,
            'user_name': currentUserName,
            'message': 'updated client details for "$cleanName"',
          });
        } catch (_) {}
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating client details: $e');
      rethrow;
    }
  }
}
