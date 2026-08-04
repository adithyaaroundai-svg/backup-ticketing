import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/contact.dart';

final customerContactsProvider = StreamProvider.family<List<Contact>, String>((
  ref,
  customerId,
) {
  final client = Supabase.instance.client;

  return client
      .from('contacts')
      .stream(primaryKey: ['id'])
      .eq('account_id', customerId)
      .order('is_primary', ascending: false)
      .order('created_at', ascending: false)
      .map((rows) => rows.map((row) => Contact.fromJson(row)).toList());
});
