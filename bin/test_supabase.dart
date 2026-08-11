import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ybmxpmsiihtasyjwxtol.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68',
  );

  try {
    final agents = await client.from('agents').select('*').limit(1);
    if (agents.isNotEmpty) {
      print('Columns: ${agents[0].keys.toList()}');
    } else {
      print('No agents found');
    }
  } catch (e) {
    print('Error: $e');
  }
}
