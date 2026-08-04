import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stream of notes for a specific customer.
final customerNotesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      customerId,
    ) {
      final supabase = Supabase.instance.client;
      return supabase
          .from('customer_notes')
          .stream(primaryKey: ['id'])
          .eq('customer_id', customerId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .map((rows) => List<Map<String, dynamic>>.from(rows));
    });
