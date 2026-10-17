import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class Deal {
  final String id;
  final String name;
  final String? companyName;
  final String date;
  final String createdAt;
  final String remark;
  final String phoneNumber;
  final String? followUpDate;
  final String? createdBy;

  Deal({
    required this.id,
    required this.name,
    this.companyName,
    required this.date,
    required this.createdAt,
    required this.remark,
    required this.phoneNumber,
    this.followUpDate,
    this.createdBy,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      companyName: json['company_name'] as String?,
      date: json['date'] as String? ?? '',
      createdAt: json['created_at'] != null ? json['created_at'].toString().substring(0, 10) : '',
      remark: json['remark'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      followUpDate: json['follow_up_date'] != null
          ? (json['follow_up_date'].toString().length >= 10
              ? json['follow_up_date'].toString().substring(0, 10)
              : json['follow_up_date'].toString())
          : null,
      createdBy: json['created_by'] as String?,
    );
  }
}

final dealsProvider = FutureProvider<List<Deal>>((ref) async {
  final currentAgent = ref.watch(authProvider);
  if (currentAgent == null) return [];

  final data = await Supabase.instance.client
      .from('deals')
      .select()
      .eq('created_by', currentAgent.id)
      .order('created_at', ascending: false);
  return (data as List).map((json) => Deal.fromJson(json)).toList();
});

final dealControllerProvider = AsyncNotifierProvider<DealController, void>(() {
  return DealController();
});

class DealController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<String?> addDeal({
    required String name,
    String? companyName,
    required String date,
    required String remark,
    required String phoneNumber,
    String? followUpDate,
  }) async {
    state = const AsyncLoading();
    try {
      final currentAgent = ref.read(authProvider);
      if (currentAgent == null) {
        throw Exception('User is not authenticated');
      }

      final sanitizedDate = date.trim().isNotEmpty
          ? date.trim()
          : DateTime.now().toIso8601String().substring(0, 10);

      final payload = <String, dynamic>{
        'name': name.trim(),
        'date': sanitizedDate,
        'remark': remark.trim(),
        'phone_number': phoneNumber.trim(),
        'created_by': currentAgent.id,
      };

      if (companyName != null && companyName.trim().isNotEmpty) {
        payload['company_name'] = companyName.trim();
      }

      if (followUpDate != null && followUpDate.trim().isNotEmpty) {
        payload['follow_up_date'] = followUpDate.trim();
      }

      print('DEBUG: Inserting deal payload: $payload');
      await Supabase.instance.client.from('deals').insert(payload);
      state = const AsyncData(null);
      ref.invalidate(dealsProvider);
      return null;
    } catch (e, st) {
      print('DEBUG: addDeal error: $e');
      if (e is PostgrestException) {
        print('DEBUG: PostgrestException: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}');
      }
      state = AsyncError(e, st);
      return e is PostgrestException ? e.message : e.toString();
    }
  }

  Future<String?> updateDeal({
    required String id,
    required String name,
    String? companyName,
    required String date,
    required String remark,
    required String phoneNumber,
    String? followUpDate,
  }) async {
    state = const AsyncLoading();
    try {
      final sanitizedDate = date.trim().isNotEmpty
          ? date.trim()
          : DateTime.now().toIso8601String().substring(0, 10);

      final updates = <String, dynamic>{
        'name': name.trim(),
        'date': sanitizedDate,
        'remark': remark.trim(),
        'phone_number': phoneNumber.trim(),
      };
      if (companyName != null) {
        updates['company_name'] = companyName.trim().isEmpty ? null : companyName.trim();
      }
      if (followUpDate != null) {
        updates['follow_up_date'] = followUpDate.trim().isEmpty ? null : followUpDate.trim();
      }
      
      print('DEBUG: Updating deal $id: $updates');
      await Supabase.instance.client.from('deals').update(updates).eq('id', id);
      state = const AsyncData(null);
      ref.invalidate(dealsProvider);
      return null;
    } catch (e, st) {
      print('DEBUG: updateDeal error: $e');
      if (e is PostgrestException) {
        print('DEBUG: PostgrestException: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}');
      }
      state = AsyncError(e, st);
      return e is PostgrestException ? e.message : e.toString();
    }
  }
}
