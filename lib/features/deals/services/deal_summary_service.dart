import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../presentation/providers/deals_provider.dart';

const String kDealRegisterChannelName = 'deal-register';

/// Initial seed recipient IDs:
/// - Anil Kumar: 14db36db-0cb9-44ef-8032-d9610b3bc797
/// - Athira: b77b3738-4dfc-4515-a1fd-d6fb170423f4
/// - Sidharth (Admin): d8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c
/// - Sidharth (Support): 4931d64c-bef5-421e-9dda-50692ea7f2a9
const String kAnilKumarUserId = '14db36db-0cb9-44ef-8032-d9610b3bc797';

const Set<String> kInitialDealRegisterRecipientIds = {
  kAnilKumarUserId, // Anil Kumar
  'b77b3738-4dfc-4515-a1fd-d6fb170423f4', // Athira
  'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c', // Sidharth anilkumar
  '4931d64c-bef5-421e-9dda-50692ea7f2a9', // Sidharth
};

/// Default checked recipients for all agents in Deals Tracker (Anil Kumar only)
const Set<String> kDefaultCheckedRecipientIds = {
  kAnilKumarUserId,
};

class DealSummaryService {
  static Timer? _schedulerTimer;
  static bool _isRunning = false;

  /// Starts the 5:00 PM background scheduler for employees who have Deals Tracker
  static void startScheduler(WidgetRef ref) {
    _schedulerTimer?.cancel();

    // Initial check
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

  /// Automatically ensures the 'deal-register' custom channel exists in Supabase
  /// and returns its channel ID.
  static Future<String?> getOrCreateDealRegisterChannel() async {
    final client = Supabase.instance.client;
    try {
      final existing = await client
          .from('custom_channels')
          .select('id, name')
          .ilike('name', 'deal%register')
          .limit(1);

      if (existing.isNotEmpty) {
        return existing.first['id'] as String;
      }

      // Create deal-register channel
      final inserted = await client.from('custom_channels').insert({
        'name': kDealRegisterChannelName,
        'is_private': true,
        'created_by': '14db36db-0cb9-44ef-8032-d9610b3bc797', // Anil Kumar
      }).select().single();

      final channelId = inserted['id'] as String;

      // Seed initial members
      for (final uid in kInitialDealRegisterRecipientIds) {
        await client.from('channel_members').insert({
          'channel_id': channelId,
          'user_id': uid,
        });
      }

      return channelId;
    } catch (e) {
      debugPrint('Error getting or creating deal-register channel: $e');
      return null;
    }
  }

  /// Fetches all member user_ids currently registered in the 'deal-register' channel
  static Future<Set<String>> getDealRegisterMemberIds() async {
    final client = Supabase.instance.client;
    try {
      final channelId = await getOrCreateDealRegisterChannel();
      if (channelId == null) return kInitialDealRegisterRecipientIds;

      final members = await client
          .from('channel_members')
          .select('user_id')
          .eq('channel_id', channelId);

      final ids = (members as List)
          .map((m) => m['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      return ids.isNotEmpty ? ids : kInitialDealRegisterRecipientIds;
    } catch (e) {
      debugPrint('Error fetching deal-register member ids: $e');
      return kInitialDealRegisterRecipientIds;
    }
  }

  /// Automatically enrolls a new recipient into the 'deal-register' channel
  static Future<bool> addMemberToDealRegister(String userId) async {
    final client = Supabase.instance.client;
    try {
      final channelId = await getOrCreateDealRegisterChannel();
      if (channelId == null) return false;

      // Check if already a member
      final existing = await client
          .from('channel_members')
          .select('id')
          .eq('channel_id', channelId)
          .eq('user_id', userId)
          .limit(1);

      if (existing.isEmpty) {
        await client.from('channel_members').insert({
          'channel_id': channelId,
          'user_id': userId,
        });
        debugPrint('DEBUG: Enrolled user $userId into deal-register channel');
      }
      return true;
    } catch (e) {
      debugPrint('Error adding member to deal-register: $e');
      return false;
    }
  }

  static const String _kPrefsKeyPrefix = 'deal_summary_recipients_v2_';

  /// Loads the sender's ticked recipient IDs from persistent storage
  static Future<Set<String>> getSelectedRecipientIds(String senderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('$_kPrefsKeyPrefix$senderId');
      if (list != null) {
        return list.toSet();
      }
    } catch (e) {
      debugPrint('Error reading selected recipients: $e');
    }
    // Default: for now, for all agents, Anil is the only checked recipient
    return Set.from(kDefaultCheckedRecipientIds);
  }

  /// Saves the sender's ticked recipient IDs
  static Future<void> saveSelectedRecipientIds(String senderId, Set<String> recipientIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_kPrefsKeyPrefix$senderId', recipientIds.toList());
    } catch (e) {
      debugPrint('Error saving selected recipients: $e');
    }
  }

  /// Fetches deals created by the sender for today
  static Future<List<Deal>> getSenderTodayDeals(String senderId) async {
    final client = Supabase.instance.client;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final data = await client
          .from('deals')
          .select()
          .eq('created_by', senderId)
          .or('date.eq.$todayStr,created_at.gte.${todayStr}T00:00:00.000Z')
          .order('created_at', ascending: false);

      return (data as List).map((j) => Deal.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getting sender today deals: $e');
      return [];
    }
  }

  /// Formats the deals into a clean structured summary (without asterisks)
  static String formatSummaryMarkdown({
    required String senderName,
    required String senderRole,
    required List<Deal> deals,
  }) {
    final now = DateTime.now();
    final dateDisplay = DateFormat('dd MMM yyyy').format(now);
    final buffer = StringBuffer();

    buffer.writeln('👤 Agent: $senderName ($senderRole)');
    buffer.writeln('📋 Daily Deals Summary — $dateDisplay');
    buffer.writeln('📦 Deals Logged Today: ${deals.length}');
    buffer.writeln('');

    if (deals.isEmpty) {
      buffer.writeln('No new deals were logged today.');
      return buffer.toString();
    }

    for (int i = 0; i < deals.length; i++) {
      final d = deals[i];
      buffer.writeln('${i + 1}. ${d.name}');
      if (d.companyName != null && d.companyName!.trim().isNotEmpty) {
        buffer.writeln('   • Company: ${d.companyName!.trim()}');
      }
      if (d.phoneNumber.trim().isNotEmpty) {
        buffer.writeln('   • Contact: ${d.phoneNumber.trim()}');
      }
      if (d.followUpDate != null && d.followUpDate!.trim().isNotEmpty) {
        String cleanFollowUp = d.followUpDate!.trim();
        try {
          final dt = DateTime.parse(cleanFollowUp);
          cleanFollowUp = DateFormat('dd MMM yyyy').format(dt);
        } catch (_) {}
        buffer.writeln('   • Follow Up: $cleanFollowUp');
      }
      if (d.remark.trim().isNotEmpty) {
        buffer.writeln('   • Remark: ${d.remark.trim()}');
      }
      buffer.writeln('');
    }

    return buffer.toString().trim();
  }

  /// Sends the daily summary to all ticked recipients
  static Future<String?> sendDailySummary({
    required WidgetRef ref,
    bool isManual = false,
    Set<String>? recipientIdsOverride,
  }) async {
    final currentAgent = ref.read(authProvider);
    if (currentAgent == null) {
      return 'User is not logged in';
    }

    final channelId = await getOrCreateDealRegisterChannel();
    if (channelId == null) {
      return 'Could not find or create deal-register channel';
    }

    final deals = await getSenderTodayDeals(currentAgent.id);
    if (deals.isEmpty && isManual) {
      return 'No deals found for today to summarize.';
    }

    final recipientIds = recipientIdsOverride ?? await getSelectedRecipientIds(currentAgent.id);
    if (recipientIds.isEmpty) {
      return 'No recipients are selected. Please select at least one recipient.';
    }

    final summaryContent = formatSummaryMarkdown(
      senderName: currentAgent.fullName,
      senderRole: currentAgent.role,
      deals: deals,
    );

    final client = Supabase.instance.client;
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    try {
      // Send an individualized message to each ticked recipient
      for (final recipientId in recipientIds) {
        await client.from('chat_messages').insert({
          'id': const Uuid().v4(),
          'sender_id': currentAgent.id,
          'receiver_id': recipientId, // Targeted recipient!
          'sender_name': currentAgent.fullName,
          'sender_role': currentAgent.role,
          'sender_avatar_url': currentAgent.avatarUrl,
          'content': summaryContent,
          'channel': channelId,
          'created_at': nowUtc,
        });
      }

      // Record that today's summary was sent
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('deal_summary_sent_${currentAgent.id}_$todayStr', true);

      return null; // Success!
    } catch (e) {
      debugPrint('Error sending daily summary: $e');
      return e.toString();
    }
  }

  /// Internal 5:00 PM check
  static Future<void> _checkAndSendIfDue(WidgetRef ref) async {
    if (_isRunning) return;

    try {
      final currentAgent = ref.read(authProvider);
      if (currentAgent == null) return;

      // Only for agents who have Deals Tracker
      if (currentAgent.isAdmin || currentAgent.isSoftwareDeveloper) return;

      final now = DateTime.now();
      // 5:00 PM or later (17:00 to 23:59)
      if (now.hour < 17) return;

      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final prefsKey = 'deal_summary_sent_${currentAgent.id}_$todayStr';

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(prefsKey) ?? false) return;

      final deals = await getSenderTodayDeals(currentAgent.id);
      if (deals.isEmpty) {
        // No deals logged today -> nothing to send
        return;
      }

      _isRunning = true;
      final err = await sendDailySummary(ref: ref, isManual: false);
      if (err == null) {
        debugPrint('DEBUG: Automatically sent 5:00 PM deal summary for ${currentAgent.fullName}');
      } else {
        debugPrint('Failed to auto-send deal summary: $err');
      }
    } catch (e) {
      debugPrint('Error in _checkAndSendIfDue: $e');
    } finally {
      _isRunning = false;
    }
  }
}
