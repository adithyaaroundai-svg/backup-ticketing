import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/advanced_settings.dart';

/// Simple app-wide feature flags loaded from the `app_settings` table.
final appSettingsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);

  final client = Supabase.instance.client;
  final response = await client.from('app_settings').select();

  final settings = <String, bool>{};
  for (final row in response as List<dynamic>) {
    final map = row as Map<String, dynamic>;
    final key = map['setting_key'] as String;
    final value = map['setting_value'] as Map<String, dynamic>;
    settings[key] = value['enabled'] as bool? ?? true;
  }
  return settings;
});

/// Advanced settings provider with role permissions and workflow config.
/// Parses structured JSON from app_settings rows with safe defaults.
final advancedSettingsProvider = FutureProvider<AdvancedSettings>((ref) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);

  final client = Supabase.instance.client;
  final response = await client.from('app_settings').select();

  final rawSettings = <String, dynamic>{};

  for (final row in response as List<dynamic>) {
    final map = row as Map<String, dynamic>;
    final key = map['setting_key'] as String;
    final value = map['setting_value'];

    if (value is Map<String, dynamic>) {
      // Check if it's a simple boolean flag or a complex config
      if (value.containsKey('enabled') && value.length == 1) {
        // Simple boolean flag
        rawSettings[key] = value['enabled'] as bool? ?? true;
      } else {
        // Complex config (role_permissions, workflow_config, etc.)
        rawSettings[key] = value;
      }
    }
  }

  return AdvancedSettings.fromRaw(rawSettings);
});
