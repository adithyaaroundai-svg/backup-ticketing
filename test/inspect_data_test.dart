import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  HttpOverrides.global = null;

  test('Inspect Supabase Data', () async {
    final client = SupabaseClient(
      'https://ybmxpmsiihtasyjwxtol.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68',
    );

    final startLocal = DateTime(2026, 9, 17, 0, 0, 0);
    final endLocal = DateTime(2026, 9, 17, 23, 59, 59, 999);
    final startUtc = startLocal.toUtc().toIso8601String();
    final endUtc = endLocal.toUtc().toIso8601String();

    print('IST: $startLocal to $endLocal');
    print('UTC: $startUtc to $endUtc');

    // 1. Created tickets
    final created = await client
        .from('tickets')
        .select('id, client_ticket_uuid, title, status, assigned_to, created_by, created_at, updated_at, completed_at, bill_amount, has_amc, customer_id, assignment_history')
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);
    print('\n=== CREATED TICKETS YESTERDAY (${created.length}) ===');
    for (final t in created) {
      print('TICKET: id=${t['id']} | title=${t['title']} | status=${t['status']} | assigned_to=${t['assigned_to']} | bill_amount=${t['bill_amount']} | created_at=${t['created_at']} | updated_at=${t['updated_at']} | completed_at=${t['completed_at']} | cust=${t['customer_id']} | has_amc=${t['has_amc']} | hist=${t['assignment_history']}');
    }

    // 2. Remarks
    final remarks = await client
        .from('ticket_remarks')
        .select('id, ticket_id, agent_id, remark, remark_type, stage, created_at')
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);
    print('\n=== TICKET REMARKS YESTERDAY (${remarks.length}) ===');
    for (final r in remarks) {
      print('REMARK: ${r['remark']} | agent=${r['agent_id']} | ticket=${r['ticket_id']} | created_at=${r['created_at']}');
    }

    // Recent remarks overall
    final recentRemarks = await client
        .from('ticket_remarks')
        .select('id, ticket_id, agent_id, remark, created_at')
        .order('created_at', ascending: false)
        .limit(10);
    print('\n=== RECENT REMARKS OVERALL (${recentRemarks.length}) ===');
    for (final r in recentRemarks) {
      print('REMARK: ${r['remark']} | agent=${r['agent_id']} | created_at=${r['created_at']}');
    }

    // 3. Comments
    final recentComments = await client
        .from('ticket_comments')
        .select('id, ticket_id, author, body, created_at')
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);
    print('\n=== TICKET COMMENTS YESTERDAY (${recentComments.length}) ===');
    for (final c in recentComments) {
      print('COMMENT: ${c['body']} | author=${c['author']} | ticket=${c['ticket_id']} | created_at=${c['created_at']}');
    }

    // 4. Audit Log
    final audit = await client
        .from('audit_log')
        .select('id, ticket_id, action, performed_by, payload, created_at')
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);
    print('\n=== AUDIT LOG YESTERDAY (${audit.length}) ===');
    for (final a in audit) {
      print('AUDIT: action=${a['action']} | by=${a['performed_by']} | ticket=${a['ticket_id']} | payload=${a['payload']} | created_at=${a['created_at']}');
    }

    // 5. Updated tickets yesterday
    final updated = await client
        .from('tickets')
        .select('id, client_ticket_uuid, title, status, assigned_to, created_by, created_at, updated_at, completed_at, bill_amount, has_amc, customer_id, assignment_history')
        .gte('updated_at', startUtc)
        .lte('updated_at', endUtc);
    print('\n=== ALL TICKETS UPDATED YESTERDAY (${updated.length}) ===');
    for (final t in updated) {
      print('UPDATED: id=${t['id']} | title=${t['title']} | status=${t['status']} | assigned_to=${t['assigned_to']} | bill_amount=${t['bill_amount']} | updated_at=${t['updated_at']} | completed_at=${t['completed_at']} | hist=${t['assignment_history']}');
    }
  });
}
