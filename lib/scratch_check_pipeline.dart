import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://ybmxpmsiihtasyjwxtol.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68';
  
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  final data = await client.from('leads').select().order('created_at', ascending: false).limit(10);
  print('Last 10 Leads:');
  for (final lead in data) {
    print('ID: ${lead['id']}, pipeline_type: ${lead['pipeline_type']}, status: ${lead['status']}, claimed_by: ${lead['claimed_by']}');
  }
  exit(0);
}
