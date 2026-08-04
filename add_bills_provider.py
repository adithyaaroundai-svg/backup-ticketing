import re
import sys

def main():
    try:
        with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'r', encoding='utf-8') as f:
            content = f.read()

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
        # Append the new provider at the end
        if 'billsTicketsProvider' not in content:
            content += '\n' + bills_provider

        with open('lib/features/tickets/presentation/providers/ticket_provider.dart', 'w', encoding='utf-8') as f:
            f.write(content)
            
        print('Success adding billsTicketsProvider')

    except Exception as e:
        print(e)
        sys.exit(1)

if __name__ == '__main__':
    main()
