import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://ybmxpmsiihtasyjwxtol.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68';
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    await client.auth.signInWithPassword(email: 'agents@tallycare.local', password: 'AgentShared#2026');
    final res = await client.from('leads').select().eq('id', '4b3cd0c9-aeff-4d0e-9714-98106e5b8e43');
    print('Lead data: $res');
    
    // Test update
    final updateRes = await client.from('leads').update({'claimed_by': 'Test'}).eq('id', '4b3cd0c9-aeff-4d0e-9714-98106e5b8e43').select();
    print('Update res: $updateRes');
  } catch (e, st) {
    print('Error: $e');
  }
  exit(0);
}
