import re
import sys

def main():
    try:
        with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'r', encoding='utf-8') as f:
            content = f.read()

        # Remove _realtimeQuery
        start_idx = content.find('Stream<List<Map<String, dynamic>>> _realtimeQuery({')
        if start_idx != -1:
            comment_idx = content.rfind('//', 0, start_idx)
            if comment_idx != -1 and start_idx - comment_idx < 200:
                end_idx = content.find('\n}\n\n', start_idx)
                if end_idx != -1:
                    content = content[:comment_idx] + content[end_idx+3:]

        # Replace overdueClaimedTicketsProvider
        overdue_pattern = r'final overdueClaimedTicketsProvider =.*?\}\);\n\}\);\n'
        overdue_replacement = '''final overdueClaimedTicketsProvider =
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
});
'''
        content = re.sub(overdue_pattern, overdue_replacement, content, flags=re.DOTALL)

        # Replace staleUnclaimedTicketsProvider
        stale_pattern = r'final staleUnclaimedTicketsProvider =.*?\}\);\n\}\);\n'
        stale_replacement = '''final staleUnclaimedTicketsProvider =
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
});
'''
        content = re.sub(stale_pattern, stale_replacement, content, flags=re.DOTALL)


        # Replace singleTicketStreamProvider
        single_pattern = r'final singleTicketStreamProvider =.*?\}\);\n\}\);\n'
        single_replacement = '''// Stream for a single ticket by its UUID
final singleTicketStreamProvider =
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
});
'''
        content = re.sub(single_pattern, single_replacement, content, flags=re.DOTALL)

        # Replace ticketAssignmentHistoryProvider
        history_pattern = r'final ticketAssignmentHistoryProvider =.*?\}\);\n\}\);\n'
        history_replacement = '''final ticketAssignmentHistoryProvider =
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
});
'''
        content = re.sub(history_pattern, history_replacement, content, flags=re.DOTALL)

        with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'w', encoding='utf-8') as f:
            f.write(content)

        print('Success replacing providers')
    except Exception as e:
        print(e)
        sys.exit(1)

if __name__ == '__main__':
    main()
