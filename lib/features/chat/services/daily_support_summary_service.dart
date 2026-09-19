import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../presentation/providers/chat_provider.dart';

/// Target Agent Configurations
const String kSaneeshaAgentId = '26a252ac-1ace-46e8-aa86-1ce7d52fe578';
const String kSupportAccountAgentId = '57d09532-e33a-4a52-8752-3a97e95a9895';

/// Accounts authorized to receive the daily support briefing in self DM ("You")
const Set<String> kSummaryRecipientAgentIds = {
  kSaneeshaAgentId,
  kSupportAccountAgentId,
};

/// Team members included in the daily performance breakdown
const Map<String, String> kSupportTeamAgents = {
  '26a252ac-1ace-46e8-aa86-1ce7d52fe578': 'Saneesha',
  '3929b7ab-12a7-4b5d-b29a-823ad6ae2d6b': 'Anugraha',
  '7a5d6b7a-6ca0-43be-a4b8-ae358c48218b': 'Swathy',
  'd1db8003-fafc-4408-9ad8-5b9719ec8830': 'Shahma',
  'f398fe3a-ea5f-4f98-9720-b3e32e798a63': 'Vismaya',
};

class DailySupportSummaryService {
  static Timer? _schedulerTimer;
  static bool _isRunning = false;

  /// Starts the background scheduler for authorized accounts (Saneesha & Support).
  /// Runs immediately on startup/login and checks periodically every 5 minutes.
  static void startScheduler(WidgetRef ref) {
    _schedulerTimer?.cancel();

    // Run initial check
    _checkAndSendIfDue(ref);

    // Periodic check every 5 minutes
    _schedulerTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkAndSendIfDue(ref);
    });
  }

  static void stopScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
  }

  /// Checks if the current logged-in user is an authorized recipient (Saneesha or Support)
  /// and if it's 9:00 AM or later, and today's summary for yesterday hasn't been sent yet.
  static Future<void> _checkAndSendIfDue(WidgetRef ref) async {
    if (_isRunning) return;

    try {
      final currentUser = ref.read(authProvider);
      if (currentUser == null || !kSummaryRecipientAgentIds.contains(currentUser.id)) {
        // Strictly only for authorized recipients
        return;
      }

      final recipientId = currentUser.id;
      final now = DateTime.now();

      // Trigger condition: Morning 9:00 AM or later (9:00 to 23:59)
      if (now.hour < 9) {
        return;
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final prefsKey = 'daily_support_summary_sent_${recipientId}_$todayStr';

      final prefs = await SharedPreferences.getInstance();
      final alreadySentLocal = prefs.getBool(prefsKey) ?? false;
      if (alreadySentLocal) {
        return;
      }

      final client = Supabase.instance.client;

      // Also double-check Supabase chat_messages to avoid duplicate if app was reloaded
      final startOfTodayUtc = DateTime(now.year, now.month, now.day, 0, 0, 0).toUtc().toIso8601String();
      final existingMessages = await client
          .from('chat_messages')
          .select('id')
          .eq('sender_id', recipientId)
          .eq('receiver_id', recipientId)
          .ilike('content', '%Daily Support Performance Summary%')
          .gte('created_at', startOfTodayUtc)
          .limit(1);

      if (existingMessages.isNotEmpty) {
        await prefs.setBool(prefsKey, true);
        return;
      }

      // Generate and send summary to this recipient's self DM
      _isRunning = true;
      await sendDailySummary(
        recipientAgentId: recipientId,
        targetYesterdayDate: now.subtract(const Duration(days: 1)),
      );
      await prefs.setBool(prefsKey, true);

      // Refresh DM list and chat
      try {
        ref.read(dmConversationsProvider.notifier).refresh();
      } catch (_) {}
    } catch (e) {
      debugPrint('DailySupportSummaryService Error: $e');
    } finally {
      _isRunning = false;
    }
  }

  /// Generates and sends the daily summary message for a specific target date (yesterday).
  static Future<void> sendDailySummary({
    String recipientAgentId = kSaneeshaAgentId,
    DateTime? targetYesterdayDate,
  }) async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final yesterday = targetYesterdayDate ?? now.subtract(const Duration(days: 1));

    // Calculate local date range for target day
    final startOfYesterdayLocal = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
    final endOfYesterdayLocal = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);

    final startUtc = startOfYesterdayLocal.toUtc().toIso8601String();
    final endUtc = endOfYesterdayLocal.toUtc().toIso8601String();
    final startUtcDate = startOfYesterdayLocal.toUtc();
    final endUtcDate = endOfYesterdayLocal.toUtc();

    final dateFormatted = DateFormat('EEEE, dd MMMM yyyy').format(yesterday);
    final timeFormatted = DateFormat('hh:mm a').format(now);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // 1. Fetch tickets created on target day
    final createdTicketsRes = await client
        .from('tickets')
        .select('id, title, status, assigned_to, created_by, created_at, updated_at, completed_at, bill_amount, has_amc, customer_id, assignment_history')
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);
    final createdTickets = List<Map<String, dynamic>>.from(createdTicketsRes as List);

    // 2. Fetch tickets updated or completed on target day
    final updatedTicketsRes = await client
        .from('tickets')
        .select('id, title, status, assigned_to, created_by, created_at, updated_at, completed_at, bill_amount, has_amc, customer_id, assignment_history')
        .or('and(updated_at.gte.$startUtc,updated_at.lte.$endUtc),and(completed_at.gte.$startUtc,completed_at.lte.$endUtc)');
    final updatedTickets = List<Map<String, dynamic>>.from(updatedTicketsRes as List);

    // 3. Fetch audit logs on target day
    final auditLogsRes = await client
        .from('audit_log')
        .select('id, ticket_id, action, performed_by, payload, created_at')
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);
    final auditLogs = List<Map<String, dynamic>>.from(auditLogsRes as List);

    // 4. Fetch remarks on target day
    final remarksRes = await client
        .from('ticket_remarks')
        .select('id, ticket_id, agent_id, remark, remark_type, stage, created_at')
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);
    final remarks = List<Map<String, dynamic>>.from(remarksRes as List);

    // 5. Fetch comments on target day
    List<Map<String, dynamic>> comments = [];
    try {
      final commentsRes = await client
          .from('ticket_comments')
          .select('id, ticket_id, author, body, created_at')
          .gte('created_at', startUtc)
          .lte('created_at', endUtc);
      comments = List<Map<String, dynamic>>.from(commentsRes as List);
    } catch (_) {}

    // Merge all tickets into a lookup map
    final allTicketsMap = <String, Map<String, dynamic>>{};
    for (final t in [...createdTickets, ...updatedTickets]) {
      final id = t['id']?.toString();
      if (id != null) allTicketsMap[id] = t;
    }

    // Fetch any tickets referenced in audit log or remarks/comments that weren't captured
    final missingTicketIds = <String>{};
    for (final a in auditLogs) {
      final tid = a['ticket_id']?.toString();
      if (tid != null && !allTicketsMap.containsKey(tid)) missingTicketIds.add(tid);
    }
    for (final r in remarks) {
      final tid = r['ticket_id']?.toString();
      if (tid != null && !allTicketsMap.containsKey(tid)) missingTicketIds.add(tid);
    }
    for (final c in comments) {
      final tid = c['ticket_id']?.toString();
      if (tid != null && !allTicketsMap.containsKey(tid)) missingTicketIds.add(tid);
    }

    if (missingTicketIds.isNotEmpty) {
      try {
        final extraTicketsRes = await client
            .from('tickets')
            .select('id, title, status, assigned_to, created_by, created_at, updated_at, completed_at, bill_amount, has_amc, customer_id, assignment_history')
            .inFilter('id', missingTicketIds.toList());
        for (final t in extraTicketsRes as List) {
          final id = t['id']?.toString();
          if (id != null) allTicketsMap[id] = Map<String, dynamic>.from(t);
        }
      } catch (_) {}
    }

    // Fetch customer AMC data for all relevant tickets
    final customerIds = allTicketsMap.values
        .map((t) => t['customer_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final customersMap = <String, Map<String, dynamic>>{};
    if (customerIds.isNotEmpty) {
      try {
        final customersRes = await client
            .from('customers')
            .select('id, name, amc_expiry_date, is_amc')
            .inFilter('id', customerIds.toList());
        for (final c in customersRes as List) {
          final id = c['id']?.toString();
          if (id != null) customersMap[id] = Map<String, dynamic>.from(c);
        }
      } catch (_) {}
    }

    // Helper: Determine if a ticket/customer has active AMC on target day
    bool isTicketAmc(Map<String, dynamic>? ticket) {
      if (ticket == null) return false;
      if (ticket['has_amc'] == true) return true;
      final customerId = ticket['customer_id']?.toString();
      if (customerId != null && customersMap.containsKey(customerId)) {
        final customer = customersMap[customerId]!;
        if (customer['is_amc'] == true) return true;
        final expiryStr = customer['amc_expiry_date']?.toString();
        if (expiryStr != null && expiryStr.isNotEmpty) {
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && !expiry.isBefore(startOfYesterdayLocal)) {
            return true;
          }
        }
      }
      return false;
    }

    // Helper: Check if a timestamp is within the target day (UTC comparison)
    bool isDateInTargetDay(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return false;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return false;
      return !dt.isBefore(startUtcDate) && !dt.isAfter(endUtcDate);
    }

    // ── Metric Calculations ──────────────────────────────────────────────────

    // 1. Total New Tickets
    final totalNewTickets = createdTickets.length;

    // 2. Claims (from assignment_history entries on target day)
    final claimedTicketsOverall = <String>{};
    final agentClaimedTickets = <String, Set<String>>{};
    for (final agentId in kSupportTeamAgents.keys) {
      agentClaimedTickets[agentId] = <String>{};
    }

    for (final ticket in allTicketsMap.values) {
      final ticketId = ticket['id']?.toString();
      if (ticketId == null) continue;

      final history = ticket['assignment_history'];
      if (history is List) {
        for (final entry in history) {
          if (entry is Map) {
            final assignedAt = entry['assigned_at']?.toString();
            final toAgentId = entry['to']?.toString();
            if (isDateInTargetDay(assignedAt)) {
              claimedTicketsOverall.add(ticketId);
              if (toAgentId != null && agentClaimedTickets.containsKey(toAgentId)) {
                agentClaimedTickets[toAgentId]!.add(ticketId);
              }
            }
          }
        }
      }
    }
    final totalClaimedCount = claimedTicketsOverall.length;

    // 3. Attended Tickets & Actions Logged
    // A ticket is attended if an agent claimed it, performed an audit log action,
    // logged a remark, or commented on target day.
    final overallAttendedTickets = <String>{};
    final agentAttendedTickets = <String, Set<String>>{};
    final agentActionsCount = <String, int>{};
    int totalActionsLogged = 0;

    for (final agentId in kSupportTeamAgents.keys) {
      agentAttendedTickets[agentId] = <String>{};
      agentActionsCount[agentId] = 0;
    }

    // Add claims to attended
    for (final entry in agentClaimedTickets.entries) {
      final agentId = entry.key;
      for (final tid in entry.value) {
        overallAttendedTickets.add(tid);
        agentAttendedTickets[agentId]!.add(tid);
        agentActionsCount[agentId] = (agentActionsCount[agentId] ?? 0) + 1;
        totalActionsLogged++;
      }
    }

    // Add audit logs to attended
    for (final audit in auditLogs) {
      final tid = audit['ticket_id']?.toString();
      final payload = audit['payload'];
      final performedById = (payload is Map ? payload['performed_by_id']?.toString() : null);
      final performedByName = audit['performed_by']?.toString();

      if (tid != null) {
        overallAttendedTickets.add(tid);
      }

      // Match agent
      for (final agentEntry in kSupportTeamAgents.entries) {
        final agentId = agentEntry.key;
        final agentName = agentEntry.value;
        if (performedById == agentId || (performedByName != null && performedByName.toLowerCase() == agentName.toLowerCase())) {
          if (tid != null) agentAttendedTickets[agentId]!.add(tid);
          agentActionsCount[agentId] = (agentActionsCount[agentId] ?? 0) + 1;
          totalActionsLogged++;
          break;
        }
      }
    }

    // Add remarks to attended
    for (final r in remarks) {
      final tid = r['ticket_id']?.toString();
      final agentId = r['agent_id']?.toString();
      if (tid != null) {
        overallAttendedTickets.add(tid);
        if (agentId != null && agentAttendedTickets.containsKey(agentId)) {
          agentAttendedTickets[agentId]!.add(tid);
          agentActionsCount[agentId] = (agentActionsCount[agentId] ?? 0) + 1;
          totalActionsLogged++;
        }
      }
    }

    // Add comments to attended
    for (final c in comments) {
      final tid = c['ticket_id']?.toString();
      final author = c['author']?.toString()?.toLowerCase();
      if (tid != null) {
        overallAttendedTickets.add(tid);
        for (final agentEntry in kSupportTeamAgents.entries) {
          if (author != null && (author == agentEntry.value.toLowerCase() || author == agentEntry.key)) {
            agentAttendedTickets[agentEntry.key]!.add(tid);
            agentActionsCount[agentEntry.key] = (agentActionsCount[agentEntry.key] ?? 0) + 1;
            totalActionsLogged++;
            break;
          }
        }
      }
    }

    final totalAttendedTicketsCount = overallAttendedTickets.length;

    // 4. Resolved / Closed Tickets
    final overallResolvedTickets = <String>{};
    final agentResolvedTickets = <String, Set<String>>{};
    for (final agentId in kSupportTeamAgents.keys) {
      agentResolvedTickets[agentId] = <String>{};
    }

    // From audit log transitions to Resolved / Closed
    for (final audit in auditLogs) {
      final action = (audit['action']?.toString() ?? '').toLowerCase();
      final payload = audit['payload'];
      final tid = audit['ticket_id']?.toString();
      if (tid == null) continue;

      String? toStatus;
      String? performedById;
      String? performedByName = audit['performed_by']?.toString();

      if (payload is Map) {
        toStatus = (payload['to']?.toString() ?? '').toLowerCase();
        performedById = payload['performed_by_id']?.toString();
      }

      final isResolvedAction = action == 'ticket_resolved' ||
          action == 'ticket_resolved_bill_raised' ||
          toStatus == 'resolved' ||
          toStatus == 'closed';

      if (isResolvedAction) {
        overallResolvedTickets.add(tid);
        // Find agent
        for (final agentEntry in kSupportTeamAgents.entries) {
          final agentId = agentEntry.key;
          final agentName = agentEntry.value;
          if (performedById == agentId || (performedByName != null && performedByName.toLowerCase() == agentName.toLowerCase())) {
            agentResolvedTickets[agentId]!.add(tid);
            break;
          }
        }
      }
    }

    // From ticket completed_at falling on target day
    for (final ticket in allTicketsMap.values) {
      final tid = ticket['id']?.toString();
      if (tid == null) continue;
      final status = (ticket['status']?.toString() ?? '').toLowerCase();
      final completedAt = ticket['completed_at']?.toString();

      if ((status == 'resolved' || status == 'closed') && isDateInTargetDay(completedAt)) {
        overallResolvedTickets.add(tid);
        final assignedTo = ticket['assigned_to']?.toString();
        if (assignedTo != null && agentResolvedTickets.containsKey(assignedTo)) {
          agentResolvedTickets[assignedTo]!.add(tid);
        }
      }
    }

    final totalResolvedCount = overallResolvedTickets.length;

    // 5. Bills Raised ON THAT PARTICULAR DAY
    // Specific Requirement: Count tickets that actually had a bill raised on that day, and its amount.
    final billedTicketIds = <String>{};
    double totalBilledAmount = 0.0;
    final agentBilledTickets = <String, Set<String>>{};
    final agentBilledAmounts = <String, double>{};

    for (final agentId in kSupportTeamAgents.keys) {
      agentBilledTickets[agentId] = <String>{};
      agentBilledAmounts[agentId] = 0.0;
    }

    // Check audit logs for bill raise events on target day
    for (final audit in auditLogs) {
      final action = audit['action']?.toString() ?? '';
      final payload = audit['payload'];
      final tid = audit['ticket_id']?.toString();
      if (tid == null) continue;

      bool isBillRaisedEvent = false;
      double billAmt = 0.0;
      String? performedById;
      String? performedByName = audit['performed_by']?.toString();

      if (action == 'ticket_resolved_bill_raised') {
        isBillRaisedEvent = true;
        if (payload is Map) {
          billAmt = (payload['amount'] as num?)?.toDouble() ?? 0.0;
          performedById = payload['performed_by_id']?.toString();
        }
      } else if (payload is Map && (payload['to'] == 'BillRaised' || payload['to'] == 'billraised')) {
        isBillRaisedEvent = true;
        billAmt = (payload['amount'] as num?)?.toDouble() ?? 0.0;
        performedById = payload['performed_by_id']?.toString();
      }

      if (isBillRaisedEvent) {
        if (billAmt == 0.0 && allTicketsMap.containsKey(tid)) {
          billAmt = (allTicketsMap[tid]!['bill_amount'] as num?)?.toDouble() ?? 0.0;
        }

        billedTicketIds.add(tid);
        totalBilledAmount += billAmt;

        // Match performing agent or ticket assigned agent
        String? matchedAgentId = performedById;
        if (matchedAgentId == null || !agentBilledTickets.containsKey(matchedAgentId)) {
          for (final agentEntry in kSupportTeamAgents.entries) {
            if (performedByName != null && performedByName.toLowerCase() == agentEntry.value.toLowerCase()) {
              matchedAgentId = agentEntry.key;
              break;
            }
          }
        }
        if (matchedAgentId == null && allTicketsMap.containsKey(tid)) {
          matchedAgentId = allTicketsMap[tid]!['assigned_to']?.toString();
        }

        if (matchedAgentId != null && agentBilledTickets.containsKey(matchedAgentId)) {
          agentBilledTickets[matchedAgentId]!.add(tid);
          agentBilledAmounts[matchedAgentId] = (agentBilledAmounts[matchedAgentId] ?? 0.0) + billAmt;
        }
      }
    }

    // Also check tickets created on target day with status BillRaised / bill_amount > 0
    for (final ticket in createdTickets) {
      final tid = ticket['id']?.toString();
      if (tid == null || billedTicketIds.contains(tid)) continue;

      final status = ticket['status']?.toString();
      final bill = (ticket['bill_amount'] as num?)?.toDouble() ?? 0.0;

      if (status == 'BillRaised' || bill > 0) {
        billedTicketIds.add(tid);
        totalBilledAmount += bill;

        final assignedTo = ticket['assigned_to']?.toString();
        if (assignedTo != null && agentBilledTickets.containsKey(assignedTo)) {
          agentBilledTickets[assignedTo]!.add(tid);
          agentBilledAmounts[assignedTo] = (agentBilledAmounts[assignedTo] ?? 0.0) + bill;
        }
      }
    }

    final totalBilledCount = billedTicketIds.length;

    // 6. Pending / In Progress
    // Total tickets created or active on target day that are not resolved/closed
    final pendingCount = allTicketsMap.values.where((t) {
      final status = (t['status']?.toString() ?? '').toLowerCase();
      final isResolved = status == 'resolved' || status == 'closed';
      return !isResolved;
    }).length;

    // 7. Resolution Rate
    final resolutionRate = totalNewTickets > 0
        ? ((totalResolvedCount / totalNewTickets) * 100).toStringAsFixed(1)
        : (totalResolvedCount > 0 ? '100.0' : '0.0');

    // ── Build Briefing Message ───────────────────────────────────────────────
    final buffer = StringBuffer();
    buffer.writeln('📊 *Daily Support Performance Summary*');
    buffer.writeln('📅 *Date:* $dateFormatted (Yesterday)');
    buffer.writeln('⏰ *Briefing Delivered:* $timeFormatted');
    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🏢 *OVERALL SUPPORT METRICS*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📥 *Total New Tickets:* $totalNewTickets');
    buffer.writeln('🎯 *Total Claimed:* $totalClaimedCount');
    buffer.writeln('💬 *Total Attended:* $totalAttendedTicketsCount tickets ($totalActionsLogged updates logged)');
    buffer.writeln('✅ *Total Resolved / Closed:* $totalResolvedCount');
    buffer.writeln('⏳ *Pending / In Progress:* $pendingCount');
    buffer.writeln('💰 *Bills Raised:* $totalBilledCount (${currencyFormat.format(totalBilledAmount)})');
    buffer.writeln('📈 *Resolution Rate:* $resolutionRate%');
    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👥 *SUPPORT TEAM BREAKDOWN*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');

    int index = 1;
    for (final entry in kSupportTeamAgents.entries) {
      final agentId = entry.key;
      final agentName = entry.value;
      final isSelf = agentId == recipientAgentId;

      final claimedCount = agentClaimedTickets[agentId]?.length ?? 0;
      final attendedSet = agentAttendedTickets[agentId] ?? <String>{};
      final attendedCount = attendedSet.length;
      final actionsCount = agentActionsCount[agentId] ?? 0;
      final resolvedCount = agentResolvedTickets[agentId]?.length ?? 0;
      final billedCount = agentBilledTickets[agentId]?.length ?? 0;
      final billedAmount = agentBilledAmounts[agentId] ?? 0.0;

      // AMC vs Non-AMC breakdown among tickets attended/worked by this agent on target day
      int agentAmc = 0;
      int agentNonAmc = 0;
      for (final tid in attendedSet) {
        final ticket = allTicketsMap[tid];
        if (isTicketAmc(ticket)) {
          agentAmc++;
        } else {
          agentNonAmc++;
        }
      }

      final label = isSelf ? '$agentName (You)' : agentName;
      buffer.writeln('');
      buffer.writeln('${index++}. 👤 *$label*');
      buffer.writeln('   • 🎯 *Claimed:* $claimedCount tickets');
      buffer.writeln('   • 💬 *Attended:* $attendedCount tickets ($actionsCount updates logged)');
      buffer.writeln('   • ✅ *Resolved:* $resolvedCount tickets');
      buffer.writeln('   • 💰 *Billed:* $billedCount (${currencyFormat.format(billedAmount)})');
      buffer.writeln('   • 🛡️ *AMC / Non-AMC:* $agentAmc AMC | $agentNonAmc Non-AMC');
    }

    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('✨ *Automated Daily Support Briefing delivered in DM ("You").*');

    final messageContent = buffer.toString();

    // Send into recipient's Self DM Chat
    await client.from('chat_messages').insert({
      'sender_id': recipientAgentId,
      'receiver_id': recipientAgentId,
      'sender_name': 'Daily Support Briefing',
      'sender_role': 'system',
      'content': messageContent,
      'channel': 'direct',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    debugPrint('DailySupportSummaryService: Successfully sent daily summary to $recipientAgentId for $dateFormatted');
  }
}
