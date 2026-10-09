import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://ybmxpmsiihtasyjwxtol.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68';
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    await client.auth.signInWithPassword(email: 'agents@tallycare.local', password: 'AgentShared#2026');
    
    // Get all mobile-app-sales messages
    final messages = await client.from('chat_messages')
        .select()
        .eq('channel', 'mobile-app-sales')
        .order('created_at', ascending: true);
        
    int fixedCount = 0;

    for (var m in messages) {
      String content = m['content'];
      if (content.contains('🎯 New Lead (Demo Requested)')) {
        // Extract company name
        final match = RegExp(r'Company:\s*(.+)$', multiLine: true).firstMatch(content);
        if (match != null) {
          final companyName = match.group(1)?.trim();
          if (companyName != null) {
            // Find the matching lead
            final leads = await client.from('leads')
                .select('id')
                .eq('pipeline_type', 'mobile-app-sales')
                .eq('company_name', companyName)
                .order('created_at', ascending: false)
                .limit(1);
                
            if (leads.isNotEmpty) {
              final correctId = leads[0]['id'];
              
              // check existing LeadID
              final oldIdMatch = RegExp(r'\[LeadID:([^\]]+)\]').firstMatch(content);
              bool needsUpdate = false;
              String newContent = content;
              
              if (oldIdMatch != null) {
                final oldId = oldIdMatch.group(1);
                if (oldId != correctId) {
                  print('Fixing message ${m['id']}: $companyName (replacing $oldId with $correctId)');
                  newContent = content.replaceAll(RegExp(r'\[LeadID:[^\]]+\]'), '[LeadID:$correctId]');
                  needsUpdate = true;
                }
              } else {
                print('Fixing message ${m['id']}: $companyName (appending $correctId)');
                newContent = '$content\n[LeadID:$correctId]';
                needsUpdate = true;
              }
              
              if (needsUpdate) {
                await client.from('chat_messages').update({'content': newContent}).eq('id', m['id']);
                fixedCount++;
              }
            } else {
              print('Warning: No lead found in DB for company: $companyName');
            }
          }
        }
      }
    }
    
    print('Fixed $fixedCount messages.');
  } catch (e, st) {
    print('Error: $e');
  }
  exit(0);
}
