import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/leave_request.dart';

class LeaveRepository {
  final SupabaseClient _client;

  LeaveRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Stream all leave requests (for HR and Admin)
  Stream<List<LeaveRequest>> streamAllLeaves() {
    return _client
        .from('leave_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => LeaveRequest.fromJson(json)).toList());
  }

  /// Stream leave requests for a specific employee
  Stream<List<LeaveRequest>> streamAgentLeaves(String agentId) {
    return _client
        .from('leave_requests')
        .stream(primaryKey: ['id'])
        .eq('agent_id', agentId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => LeaveRequest.fromJson(json)).toList());
  }

  /// Submit a new leave request
  Future<void> submitLeaveRequest({
    required String agentId,
    required String agentName,
    required String agentRole,
    required DateTime startDate,
    required DateTime endDate,
    required String leaveType,
    String? reason,
  }) async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final formattedStart = dateFormat.format(startDate);
    final formattedEnd = dateFormat.format(endDate);

    // 1. Insert leave request record
    final inserted = await _client.from('leave_requests').insert({
      'agent_id': agentId,
      'agent_name': agentName,
      'agent_role': agentRole,
      'start_date': formattedStart,
      'end_date': formattedEnd,
      'leave_type': leaveType,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      'status': 'pending',
    }).select().maybeSingle();

    debugPrint('Leave request submitted: $inserted');

    // 2. Notify all HR (and Admin) users in the notifications table
    try {
      final agentsResponse = await _client.from('agents').select('id, role, full_name');
      final dateStr = formattedStart == formattedEnd
          ? DateFormat('dd MMM yyyy').format(startDate)
          : '${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';

      final hrAgents = (agentsResponse as List<dynamic>).where((a) {
        final r = (a['role'] as String? ?? '').toLowerCase();
        return r == 'hr' ||
            r == 'human resource' ||
            r == 'human_resource' ||
            r == 'admin';
      }).toList();

      for (final hr in hrAgents) {
        final hrId = hr['id'] as String?;
        if (hrId != null && hrId != agentId) {
          await _client.from('notifications').insert({
            'user_id': hrId,
            'type': 'leave_request',
            'title': 'New Leave Request',
            'message': '$agentName ($agentRole) applied for $leaveType leave for $dateStr.',
            'link': '/leaves',
            'is_read': false,
          });
        }
      }
    } catch (e) {
      debugPrint('Error sending leave notifications to HR: $e');
    }
  }

  /// HR Approves a leave request
  Future<void> approveLeaveRequest({
    required String leaveId,
    required String agentId,
    required String hrId,
    required String hrName,
    required String dateRangeStr,
  }) async {
    await _client.from('leave_requests').update({
      'status': 'approved',
      'approved_by': hrId,
      'approved_by_name': hrName,
      'approved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', leaveId);

    // Notify the employee that their leave is approved
    try {
      await _client.from('notifications').insert({
        'user_id': agentId,
        'type': 'leave_status',
        'title': 'Leave Approved! 🎉',
        'message': 'Your leave request for $dateRangeStr was approved by $hrName.',
        'link': '/leaves',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error sending approval notification to employee: $e');
    }
  }

  /// HR Rejects a leave request
  Future<void> rejectLeaveRequest({
    required String leaveId,
    required String agentId,
    required String hrId,
    required String hrName,
    String? rejectionReason,
    required String dateRangeStr,
  }) async {
    await _client.from('leave_requests').update({
      'status': 'rejected',
      'rejection_reason': rejectionReason?.trim().isEmpty == true ? null : rejectionReason?.trim(),
      'approved_by': hrId,
      'approved_by_name': hrName,
      'approved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', leaveId);

    // Notify the employee that their leave is rejected
    try {
      final reasonText = rejectionReason?.trim().isNotEmpty == true
          ? ' Reason: "$rejectionReason"'
          : '';
      await _client.from('notifications').insert({
        'user_id': agentId,
        'type': 'leave_status',
        'title': 'Leave Request Rejected',
        'message': 'Your leave request for $dateRangeStr was rejected by $hrName.$reasonText',
        'link': '/leaves',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error sending rejection notification to employee: $e');
    }
  }

  /// Cancel a pending leave request (by the employee)
  Future<void> cancelLeaveRequest(String leaveId) async {
    await _client.from('leave_requests').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', leaveId);
  }
}
