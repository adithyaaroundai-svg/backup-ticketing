import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../domain/entities/work_item.dart';

class WorkItemEditProvider extends ChangeNotifier {
  final ApiClient api;
  final int workItemId;
  WorkItemEditProvider(this.api, this.workItemId);

  bool loading = false;
  String? error;
  WorkItem? item;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final resp = await supabase.schema('aroundtally').from('work_items').select('''
        *,
        work_item_files ( * ),
        work_item_code ( * ),
        clients ( name ),
        projects ( name ),
        author:users!work_items_author_id_fkey ( name )
      ''').eq('id', workItemId).single();

      final c = resp['clients'];
      final p = resp['projects'];
      final a = resp['author'];

      final mapped = {
        ...resp,
        'client_name': (c is Map) ? c['name'] : null,
        'project_name': (p is Map) ? p['name'] : null,
        'author_name': (a is Map) ? a['name'] : null,
        'files': resp['work_item_files'] ?? [],
        'code_blocks': resp['work_item_code'] ?? [],
      };

      item = WorkItem.fromJson(mapped);
    } catch (e) {
      debugPrint('Error loading work item: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save({
    String? title,
    String? description,
    List<int> removeFileIds = const [],
    List<UploadPart> tcpFileParts = const [],
    List<String> tcpComments = const [],
    List<UploadPart> excelFiles = const [],
    List<UploadPart> proposalFiles = const [],
    List<UploadPart> otherFiles = const [],
  }) async {
    final supabase = Supabase.instance.client;
    final updates = <String, dynamic>{};
    
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    
    if (updates.isNotEmpty) {
      await supabase.schema('aroundtally').from('work_items').update(updates).eq('id', workItemId);
    }

    if (removeFileIds.isNotEmpty) {
      await supabase.schema('aroundtally').from('work_item_files').delete().inFilter('id', removeFileIds);
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

    for (final part in allParts) {
      final path = '${DateTime.now().millisecondsSinceEpoch}_${part.filename}';
      await supabase.storage.from('dev_crm_files').uploadBinary(path, Uint8List.fromList(part.bytes));
      await supabase.schema('aroundtally').from('work_item_files').insert({
        'work_item_id': workItemId,
        'filename': part.filename,
        'storage_path': path,
        'category': categories[part] ?? 'other',
        'comment': comments[part],
      });
    }
    await load();
  }

  Future<void> delete() async {
    await Supabase.instance.client.schema('aroundtally').from('work_items').delete().eq('id', workItemId);
  }
}
