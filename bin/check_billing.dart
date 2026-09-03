import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ybmxpmsiihtasyjwxtol.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibXhwbXNpaWh0YXN5and4dG9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68',
  );

  print('Querying tasks...');
  final resp = await supabase.schema('aroundtally').from('tasks').select('id, description, status, bill_amount').inFilter('description', ['HSN Issue', 'Print alignment']);
  
  print('Tasks data:');
  for (var row in resp) {
    print(row);
  }
  
  print('Querying advances for these tasks...');
  for (var row in resp) {
    final advResp = await supabase.schema('aroundtally').from('advances').select().eq('task_id', row['id']);
    print('Advances for task ${row['id']}: $advResp');
  }
  
  exit(0);
}
