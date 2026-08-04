import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/lead.dart';

/// Simple FutureProvider that fetches leads directly from database.
/// Use ref.invalidate(leadsProvider) to refresh after any change.
final leadsProvider = FutureProvider<List<Lead>>((ref) async {
  final client = Supabase.instance.client;
  final data = await client
      .from('leads')
      .select()
      .order('created_at', ascending: false);
  final allLeads = (data as List).map((json) => Lead.fromJson(json)).toList();

  final currentUser = ref.watch(authProvider);
  const restrictedAgentIds = {
    '0a5aeeb8-9544-4dc8-920f-e26c192b0dd3',
    'f3b54de6-0372-4648-ad87-3e98089efc2d',
  };

  if (currentUser != null && restrictedAgentIds.contains(currentUser.id)) {
    return allLeads.where((l) => l.createdBy == currentUser.id).toList();
  }

  return allLeads;
});

// Keep backward-compatible stream alias
final leadsStreamProvider = leadsProvider;

final leadControllerProvider = AsyncNotifierProvider<LeadController, void>(() {
  return LeadController();
});

class LeadController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> createLead({
    required String companyName,
    required double amount,
    String status = 'pending',
  }) async {
    state = const AsyncLoading();
    try {
      await Supabase.instance.client.from('leads').insert({
        'company_name': companyName,
        'amount': amount,
        'status': status,
        'created_by': Supabase.instance.client.auth.currentUser?.id,
      });
      state = const AsyncData(null);
      // Refresh the leads list after successful insert
      ref.invalidate(leadsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateLeadStatus(String leadId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('leads')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', leadId);
      // Refresh the leads list after update
      ref.invalidate(leadsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateLeadDetails(
    String leadId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final updateData = {
        ...updates,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await Supabase.instance.client
          .from('leads')
          .update(updateData)
          .eq('id', leadId);
      // Refresh the leads list after update
      ref.invalidate(leadsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteLead(String leadId) async {
    state = const AsyncLoading();
    try {
      await Supabase.instance.client.from('leads').delete().eq('id', leadId);
      state = const AsyncData(null);
      // Refresh the leads list after delete
      ref.invalidate(leadsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

