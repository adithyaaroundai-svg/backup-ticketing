import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://ybmxpmsiihtasyjwxtol.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68';
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    // Try to select claimed_by
    final res = await client.from('leads').select('claimed_by').limit(1);
    print('Success: $res');
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}
