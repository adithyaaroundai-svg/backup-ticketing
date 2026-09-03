import '../../core/upload_part.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
      today = DateFormat('yyyy-MM-dd').format(DateTime.now());

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
    int? currentUserId,
    String? currentUserName,
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
      'created_by': currentUserId,
    }).select().single();
    
    final taskId = resp['id'];

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
  }) async {
    final supabase = Supabase.instance.client;
    
    final resp = await supabase.schema('aroundtally').from('work_items').insert({
      'client_id': clientId,
      'title': title,
      'description': description,
    }).select().single();
    
    final wId = resp['id'];
    
    if (codeSnippet != null && codeSnippet.isNotEmpty) {
      await supabase.schema('aroundtally').from('work_item_code').insert({
        'work_item_id': wId,
        'language': language ?? 'text',
        'code': codeSnippet,
      });
    }

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

    for (final part in allParts) {
      final path = '${DateTime.now().millisecondsSinceEpoch}_${part.filename}';
      await supabase.storage.from('dev_crm_files').uploadBinary(path, Uint8List.fromList(part.bytes));
      await supabase.schema('aroundtally').from('work_item_files').insert({
        'work_item_id': wId,
        'filename': part.filename,
        'storage_path': path,
        'category': categories[part] ?? 'other',
        'comment': comments[part],
      });
    }
    
    await load(tab: tab, assignee: filterAssignee);
    return wId;
  }

  Future<void> deleteWorkItem(int id) async {
    await Supabase.instance.client.schema('aroundtally').from('work_items').delete().eq('id', id);
    await load(tab: tab, assignee: filterAssignee);
  }

  Future<List<RevealedCodeBlock>> revealCode(int workItemId, String password) async {
    // For now, bypass password check and just return the code
    final resp = await Supabase.instance.client.schema('aroundtally').from('work_item_code').select('*').eq('work_item_id', workItemId);
    return (resp as List).map((e) => RevealedCodeBlock.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
