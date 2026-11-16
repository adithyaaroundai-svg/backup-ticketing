import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/client.dart';

class ClientsProvider extends ChangeNotifier {
  ClientsProvider();

  bool loading = false;
  String? error;
  List<Client> clients = [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.schema('aroundtally').from('clients').select('''
        *,
        tasks ( id, status, status_updated_at ),
        projects ( id, status )
      ''').order('id', ascending: true);

      final mapped = (response as List).map((row) {
        final tasks = row['tasks'] as List? ?? [];
        final projects = row['projects'] as List? ?? [];
        
        int openCount = 0;
        String? lastActivity;
        
        for (var t in tasks) {
          final status = t['status'];
          if (status != 'completed' && status != 'cancelled') {
            openCount++;
          }
          final statusAt = t['status_updated_at'];
          if (statusAt != null) {
            if (lastActivity == null || statusAt.compareTo(lastActivity) > 0) {
              lastActivity = statusAt;
            }
          }
        }
        
        bool ongoing = projects.any((p) => p['status'] == 'active');

        return {
          ...row,
          'open_count': openCount.toString(),
          'ongoing': ongoing,
          'last_activity': lastActivity,
        };
      }).toList();

      clients = mapped.map((e) => Client.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Error loading clients: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Client?> createClient(String name, String? contact, {int? currentUserId, String? currentUserName}) async {
    try {
      final supabase = Supabase.instance.client;
      final resp = await supabase.schema('aroundtally').from('clients').insert({
        'name': name,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
      }).select().single();
      
      final client = Client.fromJson({
        ...resp,
        'open_count': '0',
        'ongoing': false,
      });
      
      if (currentUserId != null && currentUserName != null) {
        try {
          await supabase.schema('aroundtally').from('activity_log').insert({
            'user_id': currentUserId,
            'user_name': currentUserName,
            'message': 'added new client "$name"',
          });
        } catch (e) {}
      }
      
      clients = [client, ...clients];
      notifyListeners();
      return client;
    } catch (e) {
      debugPrint('Error creating client: $e');
      return null;
    }
  }

  Future<Client?> updateClient(
    int id, {
    required String name,
    String? contact,
    int? currentUserId,
    String? currentUserName,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final cleanName = name.trim();
      final cleanContact = (contact != null && contact.trim().isNotEmpty) ? contact.trim() : null;

      final resp = await supabase.schema('aroundtally').from('clients').update({
        'name': cleanName,
        'contact': cleanContact,
      }).eq('id', id).select().single();

      final updated = Client.fromJson(resp);

      if (currentUserId != null && currentUserName != null) {
        try {
          await supabase.schema('aroundtally').from('activity_log').insert({
            'user_id': currentUserId,
            'user_name': currentUserName,
            'message': 'updated client details for "$cleanName"',
          });
        } catch (_) {}
      }

      final index = clients.indexWhere((c) => c.id == id);
      if (index != -1) {
        final existing = clients[index];
        clients[index] = Client(
          id: updated.id,
          name: updated.name,
          contact: updated.contact,
          createdAt: existing.createdAt,
          openCount: existing.openCount,
          ongoing: existing.ongoing,
          lastActivity: existing.lastActivity,
        );
      }
      notifyListeners();
      return index != -1 ? clients[index] : updated;
    } catch (e) {
      debugPrint('Error updating client: $e');
      rethrow;
    }
  }
}
