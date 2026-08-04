import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/activity.dart';

final customerActivitiesProvider =
    StreamProvider.family<List<Activity>, String>((ref, customerId) {
      final client = Supabase.instance.client;

      return client
          .from('activities')
          .stream(primaryKey: ['id'])
          .eq('account_id', customerId)
          .order('occurred_at', ascending: false)
          .map((rows) => rows.map((row) => Activity.fromJson(row)).toList());
    });
