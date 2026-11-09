import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/billing.dart';
import 'auth_provider.dart';

class BillingProvider extends ChangeNotifier {
  final AuthProvider auth; // Need auth to check if user is accountant/manager
  BillingProvider(this.auth);

  bool loading = false;
  String? error;
  BillingData? data;
  String filter = 'all'; // 'all', 'billed', 'unbilled'

  int totalCount = 0;
  int billedCount = 0;
  int unbilledCount = 0;

  void setFilter(String newFilter) {
    if (filter != newFilter) {
      filter = newFilter;
      _computeDataFromTasks();
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _cachedTasks = [];

  void _computeDataFromTasks() {
    final clientGroups = <int, Map<String, dynamic>>{};
    num grandBilled = 0;
    num grandAdvances = 0;

    for (final t in _cachedTasks) {
      final isBilled = t['billed'] == 1 || t['billed'] == true;
      if (filter == 'billed' && !isBilled) continue;
      if (filter == 'unbilled' && isBilled) continue;

      final cId = t['client_id'];
      if (cId == null) continue;

      final clientObj = t['clients'];
      final cName = (clientObj is Map) ? (clientObj['name'] ?? 'Unknown') : 'Unknown';

      if (!clientGroups.containsKey(cId)) {
        clientGroups[cId] = {
          'client': cName,
          'client_id': cId,
          'billed': 0,
          'advances': 0,
          'tasks': [],
        };
      }

      final advancesList = t['advances'] as List? ?? [];
      num advancesTotal = 0;
      for (final adv in advancesList) {
        advancesTotal += (adv['amount'] ?? 0);
      }

      final billAmount = (t['bill_amount'] != null) ? (t['bill_amount'] as num) : 0;
      final balance = billAmount - advancesTotal;

      clientGroups[cId]!['billed'] += billAmount;
      clientGroups[cId]!['advances'] += advancesTotal;
      grandBilled += billAmount;
      grandAdvances += advancesTotal;

      clientGroups[cId]!['tasks'].add({
        'id': t['id'],
        'description': t['description'],
        'status': t['status'],
        'bill_amount': billAmount,
        'billed': isBilled,
        'completed_at': t['completed_at'],
        'client_id': cId,
        'client': cName,
        'advances_total': advancesTotal,
        'balance': balance,
      });
    }

    final groups = clientGroups.values.toList();
    for (final g in groups) {
      g['balance'] = g['billed'] - g['advances'];
    }

    data = BillingData.fromJson({
      'groups': groups,
      'grand': {
        'billed': grandBilled,
        'advances': grandAdvances,
        'balance': grandBilled - grandAdvances,
      },
      'readOnly': auth.user?.role == 'accountant' || auth.user?.role == 'developer',
    });
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      // Get all tasks that are either completed OR have billed = 1 (or advances raised)
      final tasksResp = await supabase.schema('aroundtally').from('tasks').select('''
        id, description, status, bill_amount, billed, completed_at, client_id,
        clients ( name ),
        advances ( amount )
      ''').or('status.eq.completed,billed.eq.1').order('id', ascending: false);

      _cachedTasks = List<Map<String, dynamic>>.from(tasksResp as List);

      totalCount = _cachedTasks.length;
      billedCount = _cachedTasks.where((t) => t['billed'] == 1 || t['billed'] == true).length;
      unbilledCount = _cachedTasks.where((t) => t['billed'] != 1 && t['billed'] != true).length;

      _computeDataFromTasks();
    } catch (e) {
      debugPrint('Error loading billing: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateTaskBilling(
    int taskId, {
    required num billAmount,
    required bool billed,
    num? newAdvanceAmount,
    String? newAdvanceNote,
    int? currentUserId,
    String? currentUserName,
  }) async {
    final supabase = Supabase.instance.client;
    await supabase.schema('aroundtally').from('tasks').update({
      'bill_amount': billAmount,
      'billed': billed ? 1 : 0,
    }).eq('id', taskId);

    if (newAdvanceAmount != null && newAdvanceAmount > 0) {
      final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().toUtc());
      await supabase.schema('aroundtally').from('advances').insert({
        'task_id': taskId,
        'amount': newAdvanceAmount,
        'note': newAdvanceNote,
        'created_by': currentUserId,
        'created_at': nowStr,
      });
      // Raising an advance implies the task is marked for billing
      await supabase.schema('aroundtally').from('tasks').update({'billed': 1}).eq('id', taskId);
    }

    if (currentUserId != null && currentUserName != null) {
      try {
        await supabase.schema('aroundtally').from('activity_log').insert({
          'user_id': currentUserId,
          'user_name': currentUserName,
          'message': 'updated billing on task #$taskId (bill: ₹$billAmount, billed: $billed)',
        });
      } catch (_) {}
    }

    await load();
  }

  Future<void> toggleBilled(int taskId, bool isBilled) async {
    final supabase = Supabase.instance.client;
    await supabase.schema('aroundtally').from('tasks').update({
      'billed': isBilled ? 1 : 0,
    }).eq('id', taskId);
    await load();
  }
}
