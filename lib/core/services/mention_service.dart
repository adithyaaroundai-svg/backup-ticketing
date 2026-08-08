import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MentionService {
  /// Parses all @[agent_id] tokens from text and returns a set of unique agent IDs.
  static Set<String> extractMentionIds(String? text) {
    if (text == null || text.isEmpty) return {};
    final mentions = <String>{};
    
    // Match tokens in the format @[id] where id is typically a UUID or identifier
    final mentionRegExp = RegExp(r'@\[([a-zA-Z0-9\-]{1,40})\]');
    for (final match in mentionRegExp.allMatches(text)) {
      if (match.groupCount >= 1 && match.group(1) != null) {
        mentions.add(match.group(1)!);
      }
    }
    return mentions;
  }

  /// Compares oldText and newText, and sends structured notifications to newly mentioned users.
  static Future<void> processMentions({
    required String? oldText,
    required String? newText,
    required String entity,
    required String entityId,
    required String title,
    required String subtitle,
    required String highlight,
  }) async {
    try {
      final oldMentions = extractMentionIds(oldText);
      final newMentions = extractMentionIds(newText);

      // Notify only newly added mentions
      final newlyAdded = newMentions.difference(oldMentions);
      if (newlyAdded.isEmpty) return;

      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      // Prepare structured metadata for navigation
      final structuredLink = jsonEncode({
        'entity': entity,
        'entity_id': entityId,
        'highlight': highlight,
      });

      for (final targetId in newlyAdded) {
        if (targetId == currentUserId) continue; // Don't notify self

        try {
          await supabase.from('notifications').insert({
            'user_id': targetId,
            'type': 'bill_description_mention',
            'title': title,
            'message': subtitle,
            'link': structuredLink,
            'is_read': false,
          });
          debugPrint('Mention notification sent to $targetId for entity $entity ($entityId)');
        } catch (e) {
          debugPrint('Failed to insert mention notification for $targetId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in MentionService.processMentions: $e');
    }
  }
}
