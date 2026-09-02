import '../../core/parse_utils.dart';

class BillingTaskRow {
  final int id;
  final String description;
  final String status;
  final num? billAmount;
  final String? completedAt;
  final int? clientId;
  final String? client;
  final num advancesTotal;
  final num balance;

  BillingTaskRow({
    required this.id,
    required this.description,
    required this.status,
    this.billAmount,
    this.completedAt,
    this.clientId,
    this.client,
    required this.advancesTotal,
    required this.balance,
  });

  factory BillingTaskRow.fromJson(Map<String, dynamic> json) => BillingTaskRow(
        id: asInt(json['id']),
        description: asString(json['description']),
        status: asString(json['status']),
        billAmount: asNumOrNull(json['bill_amount']),
        completedAt: asStringOrNull(json['completed_at']),
        clientId: asIntOrNull(json['client_id']),
        client: asStringOrNull(json['client']),
        advancesTotal: asNum(json['advances_total']),
        balance: asNum(json['balance']),
      );
}

class BillingGroup {
  final String client;
  final int clientId;
  final num billed;
  final num advances;
  final num balance;
  final List<BillingTaskRow> tasks;

  BillingGroup({
    required this.client,
    required this.clientId,
    required this.billed,
    required this.advances,
    required this.balance,
    required this.tasks,
  });

  factory BillingGroup.fromJson(Map<String, dynamic> json) => BillingGroup(
        client: asString(json['client']),
        clientId: asInt(json['client_id']),
        billed: asNum(json['billed']),
        advances: asNum(json['advances']),
        balance: asNum(json['balance']),
        tasks: (json['tasks'] as List? ?? [])
            .map((e) => BillingTaskRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class BillingData {
  final List<BillingGroup> groups;
  final num grandBilled;
  final num grandAdvances;
  final num grandBalance;
  final bool readOnly;

  BillingData({
    required this.groups,
    required this.grandBilled,
    required this.grandAdvances,
    required this.grandBalance,
    required this.readOnly,
  });

  factory BillingData.fromJson(Map<String, dynamic> json) {
    final grand = Map<String, dynamic>.from(json['grand'] ?? {});
    return BillingData(
      groups: (json['groups'] as List? ?? [])
          .map((e) => BillingGroup.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      grandBilled: asNum(grand['billed']),
      grandAdvances: asNum(grand['advances']),
      grandBalance: asNum(grand['balance']),
      readOnly: asBool(json['readOnly']),
    );
  }
}
