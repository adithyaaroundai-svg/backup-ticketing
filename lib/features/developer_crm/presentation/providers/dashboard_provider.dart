import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../domain/entities/dashboard.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiClient api;
  DashboardProvider(this.api);

  bool loading = false;
  String? error;
  DashboardData? data;

  
  bool backingUp = false;

  Future<void> backupNow() async {
    backingUp = true;
    notifyListeners();
    // In Phase 3 this was bypassed or moved to Supabase.
    // Simulate backup delay.
    await Future.delayed(const Duration(seconds: 1));
    backingUp = false;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      // Fetch open tasks count
      final tasksResp = await supabase.schema('aroundtally').from('tasks').select('id, status').not('status', 'in', '("completed", "cancelled")');
      final openTasksCount = (tasksResp as List).length;
      
      // Fetch pending tasks count
      final pendingResp = await supabase.schema('aroundtally').from('tasks').select('id, pending').eq('pending', 1);
      final pendingCount = (pendingResp as List).length;

      // Fetch deliverables (projects in progress) count
      final projResp = await supabase.schema('aroundtally').from('projects').select('id, status').eq('status', 'active');
      final ongoingProjectsCount = (projResp as List).length;

      data = DashboardData.fromJson({
        'open_tasks_count': openTasksCount,
        'pending_tasks_count': pendingCount,
        'ongoing_projects_count': ongoingProjectsCount,
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
