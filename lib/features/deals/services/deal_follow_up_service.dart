import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/reminder_sound_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../presentation/providers/deals_provider.dart';
import '../presentation/widgets/deal_follow_up_dialog.dart';

class DealFollowUpService {
  static bool hasShownOnThisSession = false;

  /// Fetches deals created by [agentId] that have a follow-up due on or before today,
  /// excluding those that have been dismissed or are currently snoozed.
  static Future<List<Deal>> getDueFollowUpDeals(String agentId) async {
    final client = Supabase.instance.client;
    final now = DateTime.now();

    try {
      final res = await client
          .from('deals')
          .select()
          .eq('created_by', agentId)
          .not('follow_up_date', 'is', null)
          .order('follow_up_date', ascending: true);

      final list = (res as List).map((j) => Deal.fromJson(j)).toList();
      final prefs = await SharedPreferences.getInstance();

      final dueDeals = <Deal>[];
      for (final deal in list) {
        if (deal.followUpDate == null || deal.followUpDate!.trim().isEmpty) continue;

        final rawDate = deal.followUpDate!.trim();
        final dt = DateTime.tryParse(rawDate);
        if (dt == null) continue;

        final dealDay = DateTime(dt.year, dt.month, dt.day);
        final todayDay = DateTime(now.year, now.month, now.day);

        // Due if follow_up_date <= today
        if (dealDay.isAfter(todayDay)) continue;

        // Check if dismissed for this specific follow-up date
        final isDismissed = prefs.getBool('deal_fu_dismissed_${deal.id}_$rawDate') ?? false;
        if (isDismissed) continue;

        // Check if snoozed
        final snoozedUntilStr = prefs.getString('deal_fu_snoozed_until_${deal.id}');
        if (snoozedUntilStr != null) {
          final snoozedUntil = DateTime.tryParse(snoozedUntilStr);
          if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
            // Still in snooze period
            continue;
          }
        }

        dueDeals.add(deal);
      }

      return dueDeals;
    } catch (e) {
      debugPrint('Error getting due follow-up deals: $e');
      return [];
    }
  }

  /// Dismisses a follow-up reminder permanently for this specific follow-up date
  static Future<void> dismissFollowUp(String dealId, String? followUpDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (followUpDate != null && followUpDate.trim().isNotEmpty) {
        await prefs.setBool('deal_fu_dismissed_${dealId}_${followUpDate.trim()}', true);
      }
      // Also clear any existing snooze for this deal
      await prefs.remove('deal_fu_snoozed_until_$dealId');
    } catch (e) {
      debugPrint('Error dismissing follow up: $e');
    }
  }

  /// Snoozes a follow-up reminder until [snoozeUntil]
  static Future<void> snoozeFollowUp({
    required WidgetRef ref,
    required Deal deal,
    required DateTime snoozeUntil,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deal_fu_snoozed_until_${deal.id}', snoozeUntil.toIso8601String());

      // If snoozed to a different date in the future, update the deal's follow_up_date in Supabase
      final now = DateTime.now();
      final snoozeDay = DateTime(snoozeUntil.year, snoozeUntil.month, snoozeUntil.day);
      final todayDay = DateTime(now.year, now.month, now.day);

      if (snoozeDay.isAfter(todayDay)) {
        final newDateStr = DateFormat('yyyy-MM-dd').format(snoozeDay);
        await ref.read(dealControllerProvider.notifier).updateDeal(
              id: deal.id,
              name: deal.name,
              companyName: deal.companyName,
              date: deal.date,
              remark: deal.remark,
              phoneNumber: deal.phoneNumber,
              followUpDate: newDateStr,
            );
      }
    } catch (e) {
      debugPrint('Error snoozing follow up: $e');
    }
  }

  /// Checks on user login and shows the follow-up reminder dialog if deals are due
  static Future<void> checkAndShowOnLogin(BuildContext context, WidgetRef ref) async {
    if (hasShownOnThisSession) return;

    final currentAgent = ref.read(authProvider);
    if (currentAgent == null) return;
    if (currentAgent.isAdmin || currentAgent.isSoftwareDeveloper) return;

    final dueDeals = await getDueFollowUpDeals(currentAgent.id);
    if (dueDeals.isEmpty) return;

    hasShownOnThisSession = true;

    if (!context.mounted) return;

    // Play reminder sound
    ReminderSoundService.playBeep();

    // Show follow up reminder modal
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DealFollowUpDialog(
        initialDeals: dueDeals,
      ),
    );
  }
}
