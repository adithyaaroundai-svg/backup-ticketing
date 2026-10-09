import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://ybmxpmsiihtasyjwxtol.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68';
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    await client.auth.signInWithPassword(email: 'agents@tallycare.local', password: 'AgentShared#2026');
    final res = await client.from('leads').select().eq('pipeline_type', 'mobile-app-sales').limit(1);
    if (res.isNotEmpty) {
      final leadId = res[0]['id'];
      print('Updating lead $leadId...');
      final updateRes = await client.from('leads').update({'claimed_by': 'Test Agent'}).eq('id', leadId).select();
      print('Update success: $updateRes');
    } else {
      print('No leads found.');
    }
  } catch (e, st) {
    print('Error: $e');
  }
  exit(0);
}
