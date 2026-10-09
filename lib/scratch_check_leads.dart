import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://ybmxpmsiihtasyjwxtol.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68';
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    await client.auth.signInWithPassword(email: 'agents@tallycare.local', password: 'AgentShared#2026');
    final res = await client.from('leads').select('id, company_name, pipeline_type, claimed_by').order('created_at', ascending: false).limit(5);
    for (var lead in res) {
      print(lead);
    }
  } catch (e, st) {
    print('Error: $e');
  }
  exit(0);
}
