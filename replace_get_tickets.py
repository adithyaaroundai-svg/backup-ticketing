import re
import sys

def main():
    try:
        with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'r', encoding='utf-8') as f:
            content = f.read()

        # Remove _realtimeStream
        start_idx = content.find('Stream<List<Map<String, dynamic>>> _realtimeStream({')
        if start_idx != -1:
            comment_idx = content.rfind('///', 0, start_idx)
            if comment_idx != -1 and start_idx - comment_idx < 300:
                end_idx = content.find('\n}\n\n', start_idx)
                if end_idx != -1:
                    content = content[:comment_idx] + content[end_idx+3:]

        # Replace getTickets
        get_tickets_pattern = r'Stream<List<Ticket>> getTickets.*?\}\);?\n  \}'
        get_tickets_replacement = '''Stream<List<Ticket>> getTickets({String? statusFilter}) async* {
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
        content = re.sub(get_tickets_pattern, get_tickets_replacement, content, flags=re.DOTALL)

        with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'w', encoding='utf-8') as f:
            f.write(content)
            
        print('Success replacing getTickets')

    except Exception as e:
        print(e)
        sys.exit(1)

if __name__ == '__main__':
    main()
