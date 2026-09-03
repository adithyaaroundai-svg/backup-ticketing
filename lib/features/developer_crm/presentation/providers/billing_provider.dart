import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/billing.dart';
import 'auth_provider.dart';

class BillingProvider extends ChangeNotifier {
  final AuthProvider auth; // Need auth to check if user is accountant/manager
  BillingProvider(this.auth);

  bool loading = false;
  String? error;
  BillingData? data;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      // Get all unbilled, completed tasks
      final tasksResp = await supabase.schema('aroundtally').from('tasks').select('''
        id, description, status, bill_amount, completed_at, client_id,
        clients ( name ),
        advances ( amount )
      ''').eq('billed', 0).eq('status', 'completed');
      
      final clientGroups = <int, Map<String, dynamic>>{};
      num grandBilled = 0;
      num grandAdvances = 0;
      
      for (var t in tasksResp as List) {
        final cId = t['client_id'];
        if (cId == null) continue;
        
        final clientObj = t['clients'];
        final cName = (clientObj != null) ? clientObj['name'] : 'Unknown';
        
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
        for (var adv in advancesList) {
          advancesTotal += (adv['amount'] ?? 0);
        }
        
        final billAmount = t['bill_amount'] ?? 0;
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
          'completed_at': t['completed_at'],
          'client_id': cId,
          'client': cName,
          'advances_total': advancesTotal,
          'balance': balance,
        });
      }
      
      final groups = clientGroups.values.toList();
      for (var g in groups) {
        g['balance'] = g['billed'] - g['advances'];
      }
      
      data = BillingData.fromJson({
        'groups': groups,
        'grand': {
          'billed': grandBilled,
          'advances': grandAdvances,
          'balance': grandBilled - grandAdvances,
        },
        'readOnly': auth.user?.role == 'developer',
      });
    } catch (e) {
      debugPrint('Error loading billing: $e');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
