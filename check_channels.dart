import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ybmxpmsiihtasyjwxtol.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFub24iLCJpYXQiOjE3NzE5MDExNTEsImV4cCI6MjA4NzQ3NzE1MX0.dOoJWDf4j_etF0NTq4uuaVG47e0y_pDe-AdgDRhWI68',
  );

  try {
    final channels = await supabase.from('custom_channels').select();
    print('Custom channels: $channels');
    
    final members = await supabase.from('channel_members').select();
    print('Channel members: $members');
  } catch (e) {
    print('Error: $e');
  }
}
