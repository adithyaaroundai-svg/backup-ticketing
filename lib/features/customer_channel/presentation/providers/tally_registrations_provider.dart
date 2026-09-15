import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TallyRegistration {
  final String id;
  final String companyName;
  final String? companyPhone;
  final String? companyAddress;
  final DateTime createdAt;

  TallyRegistration({
    required this.id,
    required this.companyName,
    this.companyPhone,
    this.companyAddress,
    required this.createdAt,
  });

  factory TallyRegistration.fromJson(Map<String, dynamic> json) {
    return TallyRegistration(
      id: json['id'] as String,
      companyName: json['company_name'] as String? ?? 'Unknown',
      companyPhone: json['company_phone'] as String?,
      companyAddress: json['company_address'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

final tallyRegistrationsProvider = FutureProvider<List<TallyRegistration>>((ref) async {
  try {
    final response = await Supabase.instance.client.from('tally_company_registrations').select(
        'id, company_name, company_phone, company_address, created_at'
    ).order('created_at', ascending: false);
    
    print('### SUPABASE RAW RESPONSE: $response');
    
    final List<dynamic> data = response as List<dynamic>;
    return data.map((item) => TallyRegistration.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e, st) {
    print('### SUPABASE ERROR: $e');
    print(st);
    rethrow;
  }
});
