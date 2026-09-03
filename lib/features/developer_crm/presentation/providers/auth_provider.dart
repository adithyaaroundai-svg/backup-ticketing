import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';

/// Global auth state for Developer CRM.
/// Bypasses manual login by automatically matching the currently logged-in
/// Support CRM user's email against the `aroundtally.users` table.
class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  List<Task> _sidebarTasks = [];
  bool _initialized = false;
  bool _loading = false;
  String? _error;
  
  // Keep these getters since the rest of the UI relies on them
  String? get token => Supabase.instance.client.auth.currentSession?.accessToken;
  AppUser? get user => _user;
  List<Task> get sidebarTasks => _sidebarTasks;
  
  bool get isLoggedIn => _user != null;
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;
  bool get mustChangePassword => _user?.mustChangePassword ?? false;

  static const Map<String, int> agentToDevCrmIdMap = {
    '14db36db-0cb9-44ef-8032-d9610b3bc797': 1, // Anil
    'd1db8003-fafc-4408-9ad8-5b9719ec8830': 2, // Shahma
    'd7c2496a-4293-4420-9704-66c4afd26239': 3, // Neethu
    '7302b8e5-3143-4f54-9b14-5972923a833e': 4, // Sharika
    '583fcb1b-31f5-4aaa-aab8-214d5f833ef7': 5, // Archana
    '35f3d913-0cf4-4d80-93dd-593114e7e41c': 6, // Athulya
    'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c': 8, // Sidharth
  };

  /// Fetches the user from Supabase `aroundtally.users` using their mapped ID.
  Future<void> loginWithSupportId(String supportId) async {
    _loading = true;
    notifyListeners();
    
    try {
      _error = null;
      final mappedId = agentToDevCrmIdMap[supportId];
      if (mappedId == null) {
        _error = 'Support agent $supportId is not authorized for Developer CRM.';
        debugPrint(_error);
        _user = null;
        return;
      }

      final supabase = Supabase.instance.client;
      
      // Query the aroundtally schema for a matching user by id
      final response = await supabase
          .schema('aroundtally')
          .from('users')
          .select()
          .eq('id', mappedId)
          .maybeSingle();
          
      if (response != null) {
        _user = AppUser.fromJson(Map<String, dynamic>.from(response));
        
        await logActivity('Logged into Developer CRM');
        await refreshSidebarTasks();
      } else {
        _error = 'No Developer CRM user found for mapped ID: $mappedId';
        debugPrint(_error);
        _user = null;
      }
    } catch (e) {
      _error = 'Error auto-logging into Developer CRM: $e';
      debugPrint(_error);
      _user = null;
    } finally {
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  /// Global activity logger for the current user
  Future<void> logActivity(String message) async {
    if (_user == null) return;
    try {
      await Supabase.instance.client.schema('aroundtally').from('activity_log').insert({
        'user_id': _user!.id,
        'user_name': _user!.name,
        'message': message,
      });
    } catch (e) {
      debugPrint('Failed to log activity: $e');
    }
  }

  /// Refreshes the tasks in the sidebar
  Future<void> refreshSidebarTasks() async {
    if (_user == null) return;
    
    try {
      final resp = await Supabase.instance.client.schema('aroundtally').from('tasks').select('''
        *,
        clients ( name ),
        task_assignees!inner ( user_id )
      ''')
      .eq('task_assignees.user_id', _user!.id)
      .neq('status', 'completed')
      .neq('status', 'cancelled')
      .order('id', ascending: false);
      
      _sidebarTasks = (resp as List).map((row) {
        final cName = (row['clients'] is Map) ? row['clients']['name'] : null;
        return Task.fromJson({
          ...row, 
          'client': cName, 
          'assignees': [] // We only care about displaying them in sidebar
        });
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching sidebar tasks: $e');
    }
  }

  
  Future<void> changePassword({required String current, required String password, required String confirm}) async {
    if (_user != null) {
      _user = AppUser(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        role: _user!.role,
        mustChangePassword: false,
        isSuperAdmin: _user!.isSuperAdmin,
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _sidebarTasks = [];
    notifyListeners();
  }
}
