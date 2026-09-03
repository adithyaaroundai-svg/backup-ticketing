import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/activity_entry.dart';

class ActivityProvider extends ChangeNotifier {
  ActivityProvider();

  bool loading = false;
  String? error;
  List<ActivityEntry> entries = [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.schema('aroundtally').from('activity_log').select('''
        id, user_id, user_name, message, created_at
      ''').order('id', ascending: false).limit(100);

      final mapped = (response as List).map((row) {
        return {
          'id': row['id'],
          'user_id': row['user_id'],
          'user_name': row['user_name'],
          'message': row['message'],
          'created_at': row['created_at'],
        };
      }).toList();

      entries = mapped.map((e) => ActivityEntry.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading activity: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
