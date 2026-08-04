import sys

def main():
    # 1. Fix chat repository
    chat_repo = 'lib/features/chat/data/repositories/chat_repository.dart'
    with open(chat_repo, 'r', encoding='utf-8') as f:
        chat_content = f.read()
    chat_content = chat_content.replace(", rich_text_delta", "")
    with open(chat_repo, 'w', encoding='utf-8') as f:
        f.write(chat_content)

    # 2. Fix ticket repository
    ticket_repo = 'lib/features/tickets/data/repositories/supabase_ticket_repository.dart'
    with open(ticket_repo, 'r', encoding='utf-8') as f:
        ticket_content = f.read()
    ticket_content = ticket_content.replace(
        "const _ticketBaseColumns = 'id, customer_id, client_ticket_uuid, title, description, contact_phone, screenshot_url, category, status, priority, created_by, assigned_to, created_at, updated_at, sla_due, bill_amount, billing_procedure, payment_collected, has_amc, completed_at, assignment_history';",
        "const _ticketBaseColumns = 'id, customer_id, client_ticket_uuid, title, description, contact_phone, screenshot_url, category, status, priority, created_by, assigned_to, created_at, updated_at, sla_due, bill_amount, assignment_history';"
    )
    with open(ticket_repo, 'w', encoding='utf-8') as f:
        f.write(ticket_content)
        
    # 3. Fix ticket provider
    ticket_prov = 'lib/features/tickets/presentation/providers/ticket_provider.dart'
    with open(ticket_prov, 'r', encoding='utf-8') as f:
        ticket_prov_content = f.read()
    ticket_prov_content = ticket_prov_content.replace(
        ".select('id, customer_id, client_ticket_uuid, title, description, contact_phone, screenshot_url, category, status, priority, created_by, assigned_to, created_at, updated_at, sla_due, bill_amount, billing_procedure, payment_collected, has_amc, completed_at')",
        ".select('id, customer_id, client_ticket_uuid, title, description, contact_phone, screenshot_url, category, status, priority, created_by, assigned_to, created_at, updated_at, sla_due, bill_amount')"
    )
    with open(ticket_prov, 'w', encoding='utf-8') as f:
        f.write(ticket_prov_content)

if __name__ == '__main__':
    main()
