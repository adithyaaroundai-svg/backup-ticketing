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

  /// Generates and sends the daily summary message for a specific date (yesterday).
  static Future<void> sendDailySummary({
    String recipientAgentId = kSaneeshaAgentId,
    DateTime? targetYesterdayDate,
  }) async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final yesterday = targetYesterdayDate ?? now.subtract(const Duration(days: 1));

    // Calculate local date range for yesterday
    final startOfYesterdayLocal = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
    final endOfYesterdayLocal = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);

    final startUtc = startOfYesterdayLocal.toUtc().toIso8601String();
    final endUtc = endOfYesterdayLocal.toUtc().toIso8601String();

    final dateFormatted = DateFormat('EEEE, dd MMMM yyyy').format(yesterday);
    final timeFormatted = DateFormat('hh:mm a').format(now);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // 1. Fetch tickets created yesterday
    final createdTicketsRes = await client
        .from('tickets')
        .select()
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);

    final createdTickets = List<Map<String, dynamic>>.from(createdTicketsRes as List);

    // 2. Fetch tickets updated/completed yesterday
    final updatedTicketsRes = await client
        .from('tickets')
        .select()
        .or('and(updated_at.gte.$startUtc,updated_at.lte.$endUtc),and(completed_at.gte.$startUtc,completed_at.lte.$endUtc)');

    final updatedTickets = List<Map<String, dynamic>>.from(updatedTicketsRes as List);

    // Merge tickets into a map by id for lookup
    final allRelevantTickets = <String, Map<String, dynamic>>{};
    for (final t in [...createdTickets, ...updatedTickets]) {
      final id = t['id']?.toString();
      if (id != null) {
        allRelevantTickets[id] = t;
      }
    }

    // 3. Fetch all remarks logged yesterday
    final remarksRes = await client
        .from('ticket_remarks')
        .select()
        .gte('created_at', startUtc)
        .lte('created_at', endUtc);

    final remarks = List<Map<String, dynamic>>.from(remarksRes as List);

    // ── Overall Support Calculations ─────────────────────────────────────────
    final totalNewTickets = createdTickets.length;

    // Distinct tickets attended yesterday
    final attendedTicketIds = remarks.map((r) => r['ticket_id']?.toString()).whereType<String>().toSet();
    final totalAttendedTickets = attendedTicketIds.length;
    final totalRemarksLogged = remarks.length;

    // Resolved / Closed tickets yesterday
    final resolvedTickets = allRelevantTickets.values.where((t) {
      final status = (t['status']?.toString() ?? '').toLowerCase();
      final isResolvedStatus = status == 'resolved' || status == 'closed';
      if (!isResolvedStatus) return false;

      final completedAt = t['completed_at']?.toString();
      final updatedAt = t['updated_at']?.toString();

      if (completedAt != null) {
        final d = DateTime.tryParse(completedAt);
        if (d != null && d.isAfter(startOfYesterdayLocal.toUtc()) && d.isBefore(endOfYesterdayLocal.toUtc())) {
          return true;
        }
      }
      if (updatedAt != null) {
        final d = DateTime.tryParse(updatedAt);
        if (d != null && d.isAfter(startOfYesterdayLocal.toUtc()) && d.isBefore(endOfYesterdayLocal.toUtc())) {
          return true;
        }
      }
      return false;
    }).toList();

    final totalResolvedCount = resolvedTickets.length;

    // Claimed tickets
    final claimedTickets = allRelevantTickets.values.where((t) {
      final assignedTo = t['assigned_to']?.toString();
      return assignedTo != null && assignedTo.isNotEmpty;
    }).toList();
    final totalClaimedCount = claimedTickets.length;

    // In Progress / Pending tickets yesterday
    final pendingCount = allRelevantTickets.values.where((t) {
      final status = (t['status']?.toString() ?? '').toLowerCase();
      return status != 'resolved' && status != 'closed';
    }).length;

    // Billed tickets & Revenue yesterday
    double totalBilledAmount = 0.0;
    int totalBilledCount = 0;
    for (final t in allRelevantTickets.values) {
      final bill = (t['bill_amount'] as num?)?.toDouble() ?? 0.0;
      final status = (t['status']?.toString() ?? '').toLowerCase();
      if (bill > 0 || status == 'billraised' || status == 'billprocessed') {
        totalBilledCount++;
        totalBilledAmount += bill;
      }
    }

    final resolutionRate = totalNewTickets > 0
        ? ((totalResolvedCount / totalNewTickets) * 100).toStringAsFixed(1)
        : (totalResolvedCount > 0 ? '100.0' : '0.0');

    // ── Agent-by-Agent Calculations ──────────────────────────────────────────
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
    buffer.writeln('💬 *Total Attended:* $totalAttendedTickets tickets ($totalRemarksLogged remarks logged)');
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

      // Agent Remarks & Attended tickets
      final agentRemarks = remarks.where((r) => r['agent_id']?.toString() == agentId).toList();
      final agentAttendedTicketIds = agentRemarks.map((r) => r['ticket_id']?.toString()).whereType<String>().toSet();
      final agentAttendedCount = agentAttendedTicketIds.length;
      final agentRemarksCount = agentRemarks.length;

      // Agent Claimed tickets
      final agentClaimed = allRelevantTickets.values.where((t) => t['assigned_to']?.toString() == agentId).toList();
      final agentClaimedCount = agentClaimed.length;

      // Agent Resolved tickets
      final agentResolved = resolvedTickets.where((t) {
        if (t['assigned_to']?.toString() == agentId) return true;
        // Or if agent posted a resolved remark
        return agentRemarks.any((r) {
          final stage = (r['stage']?.toString() ?? '').toLowerCase();
          return r['ticket_id']?.toString() == t['id']?.toString() &&
              (stage == 'resolved' || stage == 'closed');
        });
      }).length;

      // Agent Billed tickets
      double agentBilledAmount = 0.0;
      int agentBilledCount = 0;
      for (final t in agentClaimed) {
        final bill = (t['bill_amount'] as num?)?.toDouble() ?? 0.0;
        final status = (t['status']?.toString() ?? '').toLowerCase();
        if (bill > 0 || status == 'billraised' || status == 'billprocessed') {
          agentBilledCount++;
          agentBilledAmount += bill;
        }
      }

      // AMC vs Non-AMC breakdown for tickets attended by this agent
      int agentAmc = 0;
      int agentNonAmc = 0;
      for (final tid in agentAttendedTicketIds) {
        final t = allRelevantTickets[tid];
        if (t != null) {
          final hasAmc = t['has_amc'] == true;
          if (hasAmc) {
            agentAmc++;
          } else {
            agentNonAmc++;
          }
        }
      }

      final label = isSelf ? '$agentName (You)' : agentName;
      buffer.writeln('');
      buffer.writeln('${index++}. 👤 *$label*');
      buffer.writeln('   • 🎯 *Claimed:* $agentClaimedCount tickets');
      buffer.writeln('   • 💬 *Attended:* $agentAttendedCount tickets ($agentRemarksCount updates logged)');
      buffer.writeln('   • ✅ *Resolved:* $agentResolved tickets');
      buffer.writeln('   • 💰 *Billed:* $agentBilledCount (${currencyFormat.format(agentBilledAmount)})');
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

    debugPrint('DailySupportSummaryService: Sent daily summary to $recipientAgentId for $dateFormatted');
  }
}
