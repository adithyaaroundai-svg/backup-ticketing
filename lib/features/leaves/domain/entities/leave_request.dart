import 'package:intl/intl.dart';

class LeaveRequest {
  final String id;
  final String agentId;
  final String agentName;
  final String agentRole;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveType; // 'Casual', 'Sick', 'Earned', 'Emergency', 'Half Day'
  final String? reason;
  final String status; // 'pending', 'approved', 'rejected', 'cancelled'
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LeaveRequest({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.agentRole,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.reason,
    required this.status,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  bool get isHalfDay => leaveType.toLowerCase().contains('half');

  int get totalDays {
    if (isHalfDay) return 1;
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = end.difference(start).inDays;
    return diff >= 0 ? diff + 1 : 1;
  }

  String get dateRangeFormatted {
    final fmt = DateFormat('dd MMM yyyy');
    if (isHalfDay) {
      return '${fmt.format(startDate)} (Half Day)';
    }
    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return fmt.format(startDate);
    }
    return '${fmt.format(startDate)} — ${fmt.format(endDate)}';
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return LeaveRequest(
      id: json['id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? 'Unknown',
      agentRole: json['agent_role'] as String? ?? 'Agent',
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      leaveType: json['leave_type'] as String? ?? 'Casual',
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      approvedBy: json['approved_by'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      approvedAt: json['approved_at'] != null ? parseDate(json['approved_at']) : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return {
      'agent_id': agentId,
      'agent_name': agentName,
      'agent_role': agentRole,
      'start_date': dateFormat.format(startDate),
      'end_date': dateFormat.format(endDate),
      'leave_type': leaveType,
      'reason': reason,
      'status': status,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (approvedByName != null) 'approved_by_name': approvedByName,
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
    };
  }
}
