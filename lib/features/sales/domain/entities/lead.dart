import '../../../../core/utils/json_converters.dart';

class Lead {
  final String id;
  final String companyName;
  final String status; // 'pending', 'win', 'loss', etc.
  final double amount;
  final DateTime createdAt;
  final String? createdBy;
  final String? phoneNumber;
  final String? customerName;
  final String? description;
  final DateTime? followUpDate;
  final String? owner;
  final String? source;
  final String? demoNeeded;
  final String? product;

  Lead({
    required this.id,
    required this.companyName,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.createdBy,
    this.phoneNumber,
    this.customerName,
    this.description,
    this.followUpDate,
    this.owner,
    this.source,
    this.demoNeeded,
    this.product,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? 'Unnamed Company',
      status: json['status']?.toString() ?? 'pending',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          tryParseUtcDate(json['created_at']?.toString()) ??
          DateTime.now().toUtc(),
      createdBy: json['created_by']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      customerName: json['customer_name']?.toString(),
      description: json['description']?.toString(),
      followUpDate: tryParseUtcDate(json['follow_up_date']?.toString()),
      owner: json['owner']?.toString(),
      source: json['source']?.toString(),
      demoNeeded: json['demo_needed']?.toString(),
      product: json['product']?.toString(),
    );
  }
}

