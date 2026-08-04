import sys

def main():
    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'r', encoding='utf-8') as f:
        ticket_content = f.read()

    # 1. Remove _realtimeQuery entirely
    remove_target = '''// ── Realtime stream helper (same pattern as supabase_ticket_repository) ───────
Stream<List<Map<String, dynamic>>> _realtimeQuery({
  required SupabaseClient supabase,
  required String table,
  required String channelSuffix,
  required Future<List<Map<String, dynamic>>> Function() fetcher,
}) {
  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

  Future<void> fetch() async {
    try {
      final data = await fetcher();
      if (!controller.isClosed) controller.add(data);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  fetch();

  final channel = supabase
      .channel('tp_realtime_${table}_$channelSuffix')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => fetch(),
      )
      .subscribe();

  controller.onCancel = () => supabase.removeChannel(channel);
  return controller.stream;
}

'''
    if remove_target in ticket_content:
        ticket_content = ticket_content.replace(remove_target, '')

    # 2. Add billsTicketsProvider
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

    # 3. Replace singleTicketStreamProvider
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

    # 4. Replace history provider
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

    # 5. Overdue and Stale
    overdue_old = '''final overdueClaimedTicketsProvider =
    fr.StreamProvider<List<TicketAlertEntry>>((ref) {
  final supabase = Supabase.instance.client;
  final currentUser = ref.watch(authProvider);

  if (currentUser == null) return Stream.value([]);

  return _realtimeQuery(
    supabase: supabase,
    table: 'tickets',
    channelSuffix: 'overdue_claimed',
    fetcher: () => supabase
        .from('tickets')
        .select()
        .eq('status', 'Open')
        .order('updated_at', ascending: false)
        .limit(100), // Protect against large datasets
  ).map((rows) {
    final now = DateTime.now().toUtc();
    final entries = <TicketAlertEntry>[];

    for (final raw in rows) {
      final assignedTo = raw['assigned_to'];
      if (assignedTo == null || assignedTo.toString().isEmpty) continue;
      if (assignedTo.toString() != currentUser.id) continue;

      final status = raw['status']?.toString();
      if (_isResolvedOrBilled(status)) continue;

      final assignmentAt = _extractLastAssignmentAt(raw['assignment_history']) ??
          _parseDate(raw['updated_at']) ??
          _parseDate(raw['created_at']);

      if (assignmentAt == null) continue;

      final elapsed = now.difference(assignmentAt);
      if (elapsed >= _claimedOverdueThreshold) {
        entries.add(TicketAlertEntry(
          ticket: Ticket.fromJson(Map<String, dynamic>.from(raw)),
          referenceTime: assignmentAt,
          elapsed: elapsed,
          threshold: _claimedOverdueThreshold,
        ));
      }
    }

    entries.sort((a, b) => b.elapsed.compareTo(a.elapsed));
    return entries;
  });
});'''

    overdue_new = '''final overdueClaimedTicketsProvider =
    fr.StreamProvider<List<TicketAlertEntry>>((ref) async* {
  final supabase = Supabase.instance.client;
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    yield [];
    return;
  }

  final rows = await supabase
      .from('tickets')
      .select('id, customer_id, status, assigned_to, created_at, updated_at, assignment_history')
      .eq('assigned_to', currentUser.id)
      .not('status', 'in', '("Resolved","Closed","BillProcessed","BillRaised")')
      .order('updated_at', ascending: false)
      .limit(100);

  final cache = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    cache[r['id'] as String] = r;
  }

  List<TicketAlertEntry> computeEntries() {
    final now = DateTime.now().toUtc();
    final entries = <TicketAlertEntry>[];
    for (final raw in cache.values) {
      final assignedTo = raw['assigned_to'];
      if (assignedTo == null || assignedTo.toString().isEmpty) continue;
      if (assignedTo.toString() != currentUser.id) continue;
      final status = raw['status']?.toString();
      if (_isResolvedOrBilled(status)) continue;
      final assignmentAt = _extractLastAssignmentAt(raw['assignment_history']) ??
          _parseDate(raw['updated_at']) ??
          _parseDate(raw['created_at']);
      if (assignmentAt == null) continue;
      final elapsed = now.difference(assignmentAt);
      if (elapsed >= _claimedOverdueThreshold) {
        entries.add(TicketAlertEntry(
          ticket: Ticket.fromJson(Map<String, dynamic>.from(raw)),
          referenceTime: assignmentAt,
          elapsed: elapsed,
          threshold: _claimedOverdueThreshold,
        ));
      }
    }
    entries.sort((a, b) => b.elapsed.compareTo(a.elapsed));
    return entries;
  }

  yield computeEntries();

  final repository = ref.watch(ticketRepositoryProvider);
  final stream = repository.ticketEvents.map((event) {
    final eventType = event['eventType'] as String;
    final newRecord = event['newRecord'] as Map<String, dynamic>?;
    final oldRecord = event['oldRecord'] as Map<String, dynamic>?;

    bool changed = false;
    if ((eventType == 'INSERT' || eventType == 'UPDATE') && newRecord != null) {
      final id = newRecord['id'] as String?;
      if (id != null) {
        cache[id] = newRecord;
        changed = true;
      }
    } else if (eventType == 'DELETE' && oldRecord != null) {
      final id = (oldRecord['ticket_id'] ?? oldRecord['id']) as String?;
      if (id != null && cache.containsKey(id)) {
        cache.remove(id);
        changed = true;
      }
    }
    return changed ? computeEntries() : null;
  });

  await for (final computed in stream) {
    if (computed != null) yield computed;
  }
});'''

    stale_old = '''final staleUnclaimedTicketsProvider =
    fr.StreamProvider<List<TicketAlertEntry>>((ref) {
  final supabase = Supabase.instance.client;

  return _realtimeQuery(
    supabase: supabase,
    table: 'tickets',
    channelSuffix: 'stale_unclaimed',
    fetcher: () => supabase
        .from('tickets')
        .select()
        .eq('status', 'Open')
        .order('created_at', ascending: false)
        .limit(100),
  ).map((rows) {
    final now = DateTime.now().toUtc();
    final entries = <TicketAlertEntry>[];

    for (final raw in rows) {
      final assignedTo = raw['assigned_to'];
      if (assignedTo != null && assignedTo.toString().isNotEmpty) continue;

      final status = raw['status']?.toString();
      if (_isResolvedOrBilled(status)) continue;

      final createdAt = _parseDate(raw['created_at']);
      if (createdAt == null) continue;

      final elapsed = now.difference(createdAt);
      if (elapsed >= _unclaimedOverdueThreshold) {
        entries.add(TicketAlertEntry(
          ticket: Ticket.fromJson(Map<String, dynamic>.from(raw)),
          referenceTime: createdAt,
          elapsed: elapsed,
          threshold: _unclaimedOverdueThreshold,
        ));
      }
    }

    entries.sort((a, b) => b.elapsed.compareTo(a.elapsed));
    return entries;
  });
});'''

    stale_new = '''final staleUnclaimedTicketsProvider =
    fr.StreamProvider<List<TicketAlertEntry>>((ref) async* {
  final supabase = Supabase.instance.client;

  final rows = await supabase
      .from('tickets')
      .select('id, customer_id, status, assigned_to, created_at, updated_at, assignment_history')
      .isFilter('assigned_to', null)
      .not('status', 'in', '("Resolved","Closed","BillProcessed","BillRaised")')
      .order('created_at', ascending: false)
      .limit(100);

  final cache = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    cache[r['id'] as String] = r;
  }

  List<TicketAlertEntry> computeEntries() {
    final now = DateTime.now().toUtc();
    final entries = <TicketAlertEntry>[];
    for (final raw in cache.values) {
      final assignedTo = raw['assigned_to'];
      if (assignedTo != null && assignedTo.toString().isNotEmpty) continue;
      final status = raw['status']?.toString();
      if (_isResolvedOrBilled(status)) continue;
      final createdAt = _parseDate(raw['created_at']);
      if (createdAt == null) continue;
      final elapsed = now.difference(createdAt);
      if (elapsed >= _unclaimedOverdueThreshold) {
        entries.add(TicketAlertEntry(
          ticket: Ticket.fromJson(Map<String, dynamic>.from(raw)),
          referenceTime: createdAt,
          elapsed: elapsed,
          threshold: _unclaimedOverdueThreshold,
        ));
      }
    }
    entries.sort((a, b) => b.elapsed.compareTo(a.elapsed));
    return entries;
  }

  yield computeEntries();

  final repository = ref.watch(ticketRepositoryProvider);
  final stream = repository.ticketEvents.map((event) {
    final eventType = event['eventType'] as String;
    final newRecord = event['newRecord'] as Map<String, dynamic>?;
    final oldRecord = event['oldRecord'] as Map<String, dynamic>?;

    bool changed = false;
    if ((eventType == 'INSERT' || eventType == 'UPDATE') && newRecord != null) {
      final id = newRecord['id'] as String?;
      if (id != null) {
        cache[id] = newRecord;
        changed = true;
      }
    } else if (eventType == 'DELETE' && oldRecord != null) {
      final id = (oldRecord['ticket_id'] ?? oldRecord['id']) as String?;
      if (id != null && cache.containsKey(id)) {
        cache.remove(id);
        changed = true;
      }
    }
    return changed ? computeEntries() : null;
  });

  await for (final computed in stream) {
    if (computed != null) yield computed;
  }
});'''
    ticket_content = ticket_content.replace(overdue_old, overdue_new)
    ticket_content = ticket_content.replace(stale_old, stale_new)

    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'w', encoding='utf-8') as f:
        f.write(ticket_content)


    # SUPABASE REPO
    with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'r', encoding='utf-8') as f:
        repo_content = f.read()

    remove_repo_target = '''/// Creates a realtime stream for a Supabase table that fires on ANY change
/// (INSERT, UPDATE, DELETE) — not just inserts like .stream() does.
Stream<List<Map<String, dynamic>>> _realtimeStream({
  required SupabaseClient supabase,
  required String table,
  required String channelSuffix,
  required Future<List<Map<String, dynamic>>> Function() fetcher,
}) {
  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> currentData = [];
  bool hasFetched = false;

  Future<void> fetch() async {
    try {
      final data = await fetcher();
      currentData = List<Map<String, dynamic>>.from(data);
      hasFetched = true;
      if (!controller.isClosed) controller.add(currentData);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  // Initial load
  fetch();

  // Subscribe to all changes
  final channel = supabase
      .channel('realtime_${table}_$channelSuffix')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) {
          if (!hasFetched) return;
          
          final eventType = payload.eventType;
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          if (eventType == PostgresChangeEvent.insert) {
            currentData.insert(0, newRecord);
          } else if (eventType == PostgresChangeEvent.update) {
            final index = currentData.indexWhere((item) => item['id'] == newRecord['id']);
            if (index != -1) {
              currentData[index] = newRecord;
            } else {
              // If it's updated but not in our list (e.g., due to limits or filters),
              // we can fetch again or just ignore. Ignoring is safer for egress.
              // We could insert it, but it might mess up ordering. 
            }
          } else if (eventType == PostgresChangeEvent.delete) {
            currentData.removeWhere((item) => item['id'] == oldRecord['id']);
          }
          
          if (!controller.isClosed) controller.add(List.from(currentData));
        },
      )
      .subscribe();

  controller.onCancel = () {
    supabase.removeChannel(channel);
  };

  return controller.stream;
}

'''
    if remove_repo_target in repo_content:
        repo_content = repo_content.replace(remove_repo_target, '')

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
        
    print("ALL DONE PERFECTLY")

if __name__ == '__main__':
    main()
