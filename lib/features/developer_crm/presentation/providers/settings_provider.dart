import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider();

  bool loading = false;
  String? error;
  List<AppUser> users = [];
  bool hasCodePw = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    final supabase = Supabase.instance.client;

    // Load users — separate try/catch so app_settings failure doesn't block this
    try {
      final usersResp = await supabase
          .schema('aroundtally')
          .from('users')
          .select('*')
          .order('name');
      users = (usersResp as List)
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      debugPrint('Settings: loaded ${users.length} users');
    } catch (e) {
      debugPrint('Error loading users in settings: $e');
      error = 'Failed to load users: $e';
    }

    // Load app_settings — failure is non-fatal
    try {
      final settingsResp = await supabase
          .schema('aroundtally')
          .from('app_settings')
          .select('code_password_hash')
          .eq('id', 1)
          .maybeSingle();
      hasCodePw = settingsResp != null &&
          settingsResp['code_password_hash'] != null &&
          settingsResp['code_password_hash'].toString().isNotEmpty;
    } catch (e) {
      debugPrint('app_settings not available (non-fatal): $e');
      hasCodePw = false;
    }

    loading = false;
    notifyListeners();
  }

  Future<void> setCodePassword(String password) async {
    final supabase = Supabase.instance.client;
    // Just saving plain text for now as it's an internal tool check
    await supabase.schema('aroundtally').from('app_settings').upsert({
      'id': 1,
      'code_password_hash': password,
    });
    hasCodePw = true;
    notifyListeners();
  }

  Future<void> addMember({
    required String name,
    required String email,
    String? password,
    required String role,
  }) async {
    final supabase = Supabase.instance.client;
    await supabase.schema('aroundtally').from('users').insert({
      'name': name,
      'email': email,
      'password_hash': password ?? 'no_login_allowed',
      'role': role,
    });
    await load();
  }

  Future<String> resetPassword(int userId, String password) async {
    final supabase = Supabase.instance.client;
    final resp = await supabase.schema('aroundtally').from('users').update({
      'password_hash': password,
    }).eq('id', userId).select('name').single();
    
    return resp['name']?.toString() ?? '';
  }

  String asStr(dynamic v) => v?.toString() ?? '';
}
