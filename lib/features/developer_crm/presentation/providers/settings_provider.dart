import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../domain/entities/user.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiClient api;
  SettingsProvider(this.api);

  bool loading = false;
  String? error;
  List<AppUser> users = [];
  bool hasCodePw = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final usersResp = await supabase.schema('aroundtally').from('users').select('*').order('name');
      users = (usersResp as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
      
      final settingsResp = await supabase.schema('aroundtally').from('app_settings').select('code_password_hash').eq('id', 1).maybeSingle();
      if (settingsResp != null && settingsResp['code_password_hash'] != null && settingsResp['code_password_hash'].toString().isNotEmpty) {
        hasCodePw = true;
      } else {
        hasCodePw = false;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
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
