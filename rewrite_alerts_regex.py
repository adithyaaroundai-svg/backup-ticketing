import re

def main():
    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. replace overdueClaimedTicketsProvider
    overdue_pattern = re.compile(r'final overdueClaimedTicketsProvider =.*?\}\);\n\}\);', re.DOTALL)
    
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

    content = overdue_pattern.sub(overdue_new, content, count=1)

    # 2. replace staleUnclaimedTicketsProvider
    stale_pattern = re.compile(r'final staleUnclaimedTicketsProvider =.*?\}\);\n\}\);', re.DOTALL)

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

    content = stale_pattern.sub(stale_new, content, count=1)

    with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'w', encoding='utf-8') as f:
        f.write(content)

    # NOW FIX SUPABASE REPO
    with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'r', encoding='utf-8') as f:
        repo_content = f.read()

    # It looks like there are OTHER usages of _realtimeStream in supabase_ticket_repository!
    # Let's grep where they are:
    # 95: _realtimeStream
    # 155: _realtimeStream
    # 440: _realtimeStream
    # 463: _realtimeStream
    # Let's just remove ALL occurrences of _realtimeStream usage by replacing them with the new singleton logic.
    # WAIT! The old `supabase_ticket_repository.dart` had multiple other streams! Like `getTicketDetails`, `getTicketsByCustomer`, etc.
    # I never refactored those to use the global stream in my previous steps!
    pass # I'll do this carefully.

if __name__ == '__main__':
    main()
