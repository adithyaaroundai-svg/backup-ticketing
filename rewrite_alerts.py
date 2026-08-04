import sys

def main():
    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'r', encoding='utf-8') as f:
        content = f.read()

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
    content = content.replace(overdue_old, overdue_new)
    content = content.replace(stale_old, stale_new)

    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'w', encoding='utf-8') as f:
        f.write(content)
        
    print("Done alerts")

if __name__ == '__main__':
    main()
