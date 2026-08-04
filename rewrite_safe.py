import sys

def main():
    # 1. Update ticket_provider.dart
    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'r', encoding='utf-8') as f:
        ticket_content = f.read()

    # Remove _realtimeQuery
    start_str = "Stream<List<Map<String, dynamic>>> _realtimeQuery({\n"
    start_idx = ticket_content.find(start_str)
    if start_idx != -1:
        comment_idx = ticket_content.rfind('// ──', 0, start_idx)
        if comment_idx == -1:
            comment_idx = ticket_content.rfind('// ', 0, start_idx)
        end_idx = ticket_content.find('}\n\n', start_idx)
        if end_idx != -1:
            ticket_content = ticket_content[:comment_idx] + ticket_content[end_idx+3:]

    bills_provider = '''
final billsTicketsProvider = fr.StreamProvider<List<Ticket>>((ref) async* {
  final supabase = Supabase.instance.client;
  
  final rows = await supabase
      .from('tickets')
      .select('id, customer_id, client_ticket_uuid, title, description, contact_phone, screenshot_url, category, status, priority, created_by, assigned_to, created_at, updated_at, sla_due, bill_amount, billing_procedure, payment_collected, has_amc, completed_at')
      .or('status.eq.BillRaised,status.eq.BillProcessed,and(status.eq.Closed,bill_amount.gt.0)')
      .order('updated_at', ascending: false)
      .limit(200);

  final cache = <String, Ticket>{};
  for (final r in rows) {
    final t = Ticket.fromJson(r);
    cache[t.ticketId] = t;
  }

  yield cache.values.toList();

  final repository = ref.watch(ticketRepositoryProvider);
  final stream = repository.ticketEvents.map((event) {
    final eventType = event['eventType'] as String;
    final newRecord = event['newRecord'] as Map<String, dynamic>?;
    final oldRecord = event['oldRecord'] as Map<String, dynamic>?;

    bool changed = false;
    if ((eventType == 'INSERT' || eventType == 'UPDATE') && newRecord != null) {
      final t = Ticket.fromJson(newRecord);
      final hasBillAmount = (t.billAmount ?? 0) > 0;
      final isBillTicket = t.status == 'BillRaised' ||
          t.status == 'BillProcessed' ||
          (t.status == 'Closed' && hasBillAmount);
          
      if (isBillTicket) {
        cache[t.ticketId] = t;
        changed = true;
      } else if (cache.containsKey(t.ticketId)) {
        cache.remove(t.ticketId);
        changed = true;
      }
    } else if (eventType == 'DELETE' && oldRecord != null) {
      final id = (oldRecord['ticket_id'] ?? oldRecord['id']) as String?;
      if (id != null && cache.containsKey(id)) {
        cache.remove(id);
        changed = true;
      }
    }
    
    if (changed) {
      final list = cache.values.toList();
      list.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      return list;
    }
    return null;
  });

  await for (final computed in stream) {
    if (computed != null) yield computed;
  }
});
'''
    if 'billsTicketsProvider' not in ticket_content:
        ticket_content += '\n' + bills_provider


    single_provider_old = '''final singleTicketStreamProvider =
    fr.StreamProvider.autoDispose.family<Ticket?, String>((ref, ticketId) {
  final supabase = Supabase.instance.client;
  return _realtimeQuery(
    supabase: supabase,
    table: 'tickets',
    channelSuffix: 'single_$ticketId',
    fetcher: () => supabase
        .from('tickets')
        .select()
        .eq('id', ticketId)
        .limit(1),
  ).map((rows) =>
      rows.isEmpty ? null : Ticket.fromJson(Map<String, dynamic>.from(rows.first)));
});'''

    single_provider_new = '''final singleTicketStreamProvider =
    fr.StreamProvider.autoDispose.family<Ticket?, String>((ref, ticketId) async* {
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('tickets')
      .select()
      .eq('id', ticketId)
      .limit(1);
      
  Ticket? ticket = rows.isEmpty ? null : Ticket.fromJson(Map<String, dynamic>.from(rows.first));
  yield ticket;

  final repository = ref.watch(ticketRepositoryProvider);
  final stream = repository.ticketEvents.map((event) {
    final eventType = event['eventType'] as String;
    final newRecord = event['newRecord'] as Map<String, dynamic>?;
    if ((eventType == 'INSERT' || eventType == 'UPDATE') && newRecord != null) {
      if (newRecord['id'] == ticketId) {
        ticket = Ticket.fromJson(newRecord);
        return ticket;
      }
    }
    return null;
  });

  await for (final computed in stream) {
    if (computed != null) yield computed;
  }
});'''
    ticket_content = ticket_content.replace(single_provider_old, single_provider_new)

    history_provider_old = '''final ticketAssignmentHistoryProvider =
    fr.StreamProvider.family<List<Map<String, dynamic>>, String>((ref, ticketId) {
  final supabase = Supabase.instance.client;
  return _realtimeQuery(
    supabase: supabase,
    table: 'tickets',
    channelSuffix: 'assignment_history_$ticketId',
    fetcher: () => supabase
        .from('tickets')
        .select('assignment_history')
        .eq('id', ticketId)
        .limit(1),
  ).map((rows) {
    if (rows.isEmpty) return <Map<String, dynamic>>[];
    final raw = rows.first['assignment_history'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  });
});'''

    history_provider_new = '''final ticketAssignmentHistoryProvider =
    fr.StreamProvider.family<List<Map<String, dynamic>>, String>((ref, ticketId) async* {
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('tickets')
      .select('assignment_history')
      .eq('id', ticketId)
      .limit(1);

  List<Map<String, dynamic>> parseHistory(List<dynamic> rows) {
    if (rows.isEmpty) return <Map<String, dynamic>>[];
    final raw = rows.first['assignment_history'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  yield parseHistory(rows);

  final repository = ref.watch(ticketRepositoryProvider);
  final stream = repository.ticketEvents.map((event) {
    final eventType = event['eventType'] as String;
    final newRecord = event['newRecord'] as Map<String, dynamic>?;
    if ((eventType == 'INSERT' || eventType == 'UPDATE') && newRecord != null) {
      if (newRecord['id'] == ticketId) {
        return parseHistory([newRecord]);
      }
    }
    return null;
  });

  await for (final computed in stream) {
    if (computed != null) yield computed;
  }
});'''

    ticket_content = ticket_content.replace(history_provider_old, history_provider_new)

    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'w', encoding='utf-8') as f:
        f.write(ticket_content)
        
    print("Done ticket_provider")

    # 2. Update supabase_ticket_repository.dart
    with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'r', encoding='utf-8') as f:
        repo_content = f.read()

    start_str = "Stream<List<Map<String, dynamic>>> _realtimeStream({\n"
    start_idx = repo_content.find(start_str)
    if start_idx != -1:
        comment_idx = repo_content.rfind('/// ', 0, start_idx)
        end_idx = repo_content.find('}\n\n', start_idx)
        if end_idx != -1:
            repo_content = repo_content[:comment_idx] + repo_content[end_idx+3:]

    get_tickets_old = '''  @override
  Stream<List<Ticket>> getTickets({String? statusFilter}) {
    return _realtimeStream(
      supabase: _supabase,
      table: 'tickets',
      channelSuffix: 'all_${statusFilter ?? 'none'}',
      fetcher: () => _supabase
          .from('tickets')
          .select(_ticketFullColumns)
          .order('created_at', ascending: false)
          .limit(500),
    ).map((list) {
      var tickets = list.map((map) => Ticket.fromJson(map)).toList();
      if (statusFilter == 'Open') {
        tickets = tickets
            .where((t) => [
                  'New', 'Open', 'In Progress',
                  'Waiting for Customer', 'BillRaised',
                ].contains(t.status))
            .toList();
      } else if (statusFilter == 'Closed') {
        tickets = tickets
            .where((t) => ['Resolved', 'Closed', 'BillProcessed'].contains(t.status))
            .toList();
      }
      return tickets;
    });
  }'''

    get_tickets_new = '''  @override
  Stream<List<Ticket>> getTickets({String? statusFilter}) async* {
    final rows = await _supabase
        .from('tickets')
        .select(_ticketFullColumns)
        .order('created_at', ascending: false)
        .limit(500);

    final cache = <String, Ticket>{};
    for (final r in rows) {
      final t = Ticket.fromJson(r);
      cache[t.ticketId] = t;
    }
    
    List<Ticket> getFiltered() {
      var list = cache.values.toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      if (statusFilter == 'Open') {
        return list.where((t) => [
          'New', 'Open', 'In Progress', 'Waiting for Customer', 'BillRaised'
        ].contains(t.status)).toList();
      } else if (statusFilter == 'Closed') {
        return list.where((t) => [
          'Resolved', 'Closed', 'BillProcessed'
        ].contains(t.status)).toList();
      }
      return list;
    }

    yield getFiltered();

    await for (final event in ticketEvents) {
      final eventType = event['eventType'] as String;
      final newRecord = event['newRecord'] as Map<String, dynamic>?;
      final oldRecord = event['oldRecord'] as Map<String, dynamic>?;

      bool changed = false;
      if ((eventType == 'INSERT' || eventType == 'UPDATE') && newRecord != null) {
        final t = Ticket.fromJson(newRecord);
        cache[t.ticketId] = t;
        changed = true;
      } else if (eventType == 'DELETE' && oldRecord != null) {
        final id = (oldRecord['ticket_id'] ?? oldRecord['id']) as String?;
        if (id != null && cache.containsKey(id)) {
          cache.remove(id);
          changed = true;
        }
      }
      
      if (changed) {
        yield getFiltered();
      }
    }
  }'''

    repo_content = repo_content.replace(get_tickets_old, get_tickets_new)

    with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'w', encoding='utf-8') as f:
        f.write(repo_content)
        
    print("Done repo")

if __name__ == '__main__':
    main()
