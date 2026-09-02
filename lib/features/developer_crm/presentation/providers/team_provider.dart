import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../domain/entities/team.dart';

class TeamProvider extends ChangeNotifier {
  final ApiClient api;
  TeamProvider(this.api);

  bool loading = false;
  String? error;
  List<TeamMemberRow> team = [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      // Fetch users
      final usersResp = await supabase.schema('aroundtally').from('users').select('*').order('name');
      
      // Fetch active assignments (tasks currently being worked on by the user)
      final assignmentsResp = await supabase.schema('aroundtally').from('task_assignees').select('''
        user_id,
        tasks!inner (
          id, description, status, time_spent_seconds, timer_started_at,
          clients ( id, name )
        )
      ''').eq('tasks.status', 'working');
      
      final mapped = <TeamMemberRow>[];
      
      for (var u in usersResp) {
        final uId = u['id'];
        final userAssignments = (assignmentsResp as List).where((a) => a['user_id'] == uId).toList();
        
        int totalSeconds = 0;
        final tasksList = <Map<String, dynamic>>[];
        
        for (var a in userAssignments) {
          final t = a['tasks'];
          if (t == null) continue;
          
          final client = t['clients'];
          
          final ts = t['time_spent_seconds'] ?? 0;
          totalSeconds += (ts as num).toInt();
          // live ticking handled client side
          
          tasksList.add({
            'user_id': uId,
            'id': t['id'],
            'description': t['description'],
            'status': t['status'],
            'time_spent_seconds': ts,
            'timer_started_at': t['timer_started_at'],
            'client_id': client != null ? client['id'] : null,
            'client': client != null ? client['name'] : null,
            'seconds': ts,
            'running': t['status'] == 'working',
          });
        }
        
        mapped.add(TeamMemberRow.fromJson({
          'id': uId,
          'name': u['name'],
          'role': u['role'],
          'total': totalSeconds,
          'tasks': tasksList,
        }));
      }
      
      team = mapped;
    } catch (e) {
      debugPrint('Error loading team: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
