import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/dashboard.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider();

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
      final response = await supabase.schema('aroundtally').rpc('get_dashboard_data');
      data = DashboardData.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
