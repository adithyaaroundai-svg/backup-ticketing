import '../../core/parse_utils.dart';

class DashboardCards {
  final int activeTasks;
  final int overdue;
  final int workingNow;
  final int completedWeek;

  DashboardCards({
    required this.activeTasks,
    required this.overdue,
    required this.workingNow,
    required this.completedWeek,
  });

  factory DashboardCards.fromJson(Map<String, dynamic> json) => DashboardCards(
        activeTasks: asInt(json['active_tasks']),
        overdue: asInt(json['overdue']),
        workingNow: asInt(json['working_now']),
        completedWeek: asInt(json['completed_week']),
      );
}

class DashboardMoney {
  final num billed;
  final num advances;
  final num balance;

  DashboardMoney({required this.billed, required this.advances, required this.balance});

  factory DashboardMoney.fromJson(Map<String, dynamic> json) => DashboardMoney(
        billed: asNum(json['billed']),
        advances: asNum(json['advances']),
        balance: asNum(json['balance']),
      );
}

class DashboardClientRow {
  final String name;
  final num billed;
  final num advances;
  final num balance;
  final int seconds;
  final num hours;
  final num? rate;

  DashboardClientRow({
    required this.name,
    required this.billed,
    required this.advances,
    required this.balance,
    required this.seconds,
    required this.hours,
    this.rate,
  });

  factory DashboardClientRow.fromJson(Map<String, dynamic> json) => DashboardClientRow(
        name: asString(json['name']),
        billed: asNum(json['billed']),
        advances: asNum(json['advances']),
        balance: asNum(json['balance']),
        seconds: asInt(json['seconds']),
        hours: asNum(json['hours']),
        rate: asNumOrNull(json['rate']),
      );
}

class DashboardDeveloperRow {
  final String name;
  final String role;
  final int active;
  final int completedWeek;
  final int workingNow;
  final int seconds;

  DashboardDeveloperRow({
    required this.name,
    required this.role,
    required this.active,
    required this.completedWeek,
    required this.workingNow,
    required this.seconds,
  });

  factory DashboardDeveloperRow.fromJson(Map<String, dynamic> json) => DashboardDeveloperRow(
        name: asString(json['name']),
        role: asString(json['role']),
        active: asInt(json['active']),
        completedWeek: asInt(json['completed_week']),
        workingNow: asInt(json['working_now']),
        seconds: asInt(json['seconds']),
      );
}

class BackupInfo {
  final String? objectKey;
  final int? sizeBytes;
  final String? status;
  final String? createdAt;

  BackupInfo({this.objectKey, this.sizeBytes, this.status, this.createdAt});

  factory BackupInfo.fromJson(Map<String, dynamic> json) => BackupInfo(
        objectKey: asStringOrNull(json['object_key']),
        sizeBytes: asIntOrNull(json['size_bytes']),
        status: asStringOrNull(json['status']),
        createdAt: asStringOrNull(json['created_at']),
      );
}

class DashboardData {
  final DashboardCards cards;
  final DashboardMoney money;
  final List<DashboardClientRow> clients;
  final List<DashboardDeveloperRow> developers;
  final BackupInfo? lastBackup;
  final String weekStart;

  DashboardData({
    required this.cards,
    required this.money,
    required this.clients,
    required this.developers,
    this.lastBackup,
    required this.weekStart,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        cards: DashboardCards.fromJson(Map<String, dynamic>.from(json['cards'] ?? {})),
        money: DashboardMoney.fromJson(Map<String, dynamic>.from(json['money'] ?? {})),
        clients: (json['clients'] as List? ?? [])
            .map((e) => DashboardClientRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        developers: (json['developers'] as List? ?? [])
            .map((e) => DashboardDeveloperRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        lastBackup: json['lastBackup'] == null
            ? null
            : BackupInfo.fromJson(Map<String, dynamic>.from(json['lastBackup'])),
        weekStart: asString(json['weekStart']),
      );
}
