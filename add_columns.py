import sys

def main():
    with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'r', encoding='utf-8') as f:
        content = f.read()
        
    cols = """
const _ticketBaseColumns = 'id, customer_id, client_ticket_uuid, title, description, contact_phone, screenshot_url, category, status, priority, created_by, assigned_to, created_at, updated_at, sla_due, bill_amount, billing_procedure, payment_collected, has_amc, completed_at, assignment_history';
const _ticketFullColumns = _ticketBaseColumns;
const _ticketAlertColumns = 'id, customer_id, status, assigned_to, created_at, updated_at, assignment_history';

class SupabaseTicketRepository implements TicketRepository {"""
    
    if '_ticketFullColumns' not in content:
        content = content.replace('class SupabaseTicketRepository implements TicketRepository {', cols)
        with open('lib/features/tickets/data/repositories/supabase_ticket_repository.dart', 'w', encoding='utf-8') as f:
            f.write(content)

if __name__ == '__main__':
    main()
