import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/task.dart';

class DeliverablesProvider extends ChangeNotifier {
  DeliverablesProvider();

  bool loading = false;
  String? error;
  List<Task> todayDue = [];
  List<Task> tomorrowDue = [];
  List<Task> delayed = [];
  String? today;
  String? tomorrow;

  Map<String, dynamic> _mapTask(Map<String, dynamic> row) {
    final clientObj = row['clients'];
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
    return {
      ...row,
      'client': (clientObj is Map) ? clientObj['name'] : null,
      'assignees': assignees,
      'files': row['task_files'] ?? [],
      'advances_total': 0, // Not needed for deliverables view usually
    };
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
      
      today = todayStr;
      tomorrow = tomorrowStr;

      // Fetch all non-completed/non-cancelled tasks with an expected finish date
      final response = await supabase.schema('aroundtally').from('tasks').select('''
        *,
        clients ( name ),
        task_assignees ( user_id, users ( name ) ),
        task_files ( * )
      ''').not('status', 'in', '("completed", "cancelled")').not('expected_finish', 'is', 'null');

      final allDue = (response as List).map((row) => _mapTask(Map<String, dynamic>.from(row))).map((e) => Task.fromJson(e)).toList();

      todayDue = [];
      tomorrowDue = [];
      delayed = [];

      for (var t in allDue) {
        final ef = t.expectedFinish;
        if (ef == null) continue;
        if (ef == todayStr) {
          todayDue.add(t);
        } else if (ef == tomorrowStr) {
          tomorrowDue.add(t);
        } else if (ef.compareTo(todayStr) < 0) {
          delayed.add(t);
        }
      }
    } catch (e) {
      debugPrint('Error loading deliverables: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
