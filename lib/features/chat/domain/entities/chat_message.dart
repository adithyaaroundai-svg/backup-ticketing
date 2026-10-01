import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/utils/json_converters.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'receiver_id') String? receiverId,
    @JsonKey(name: 'sender_name') required String senderName,
    @JsonKey(name: 'sender_role') required String senderRole,
    @JsonKey(name: 'sender_avatar_url') String? senderAvatarUrl,
    required String content,
    @JsonKey(name: 'created_at') @UtcDateTimeConverter() required DateTime createdAt,
    @Default(false) @JsonKey(name: 'is_deleted') bool isDeleted,
    @Default([]) @JsonKey(name: 'reactions') List<Map<String, dynamic>> reactions,
    @JsonKey(name: 'reply_to_message_id') String? replyToMessageId,
    @JsonKey(name: 'reply_to_sender_name') String? replyToSenderName,
    @JsonKey(name: 'reply_to_content') String? replyToContent,
    @JsonKey(name: 'file_url') String? fileUrl,
    @JsonKey(name: 'file_name') String? fileName,
    @JsonKey(name: 'file_type') String? fileType,
    @Default('support-chat') @JsonKey(name: 'channel') String channel,
    @Default(false) @JsonKey(name: 'is_forwarded') bool isForwarded,
    @Default(false) @JsonKey(name: 'is_edited') bool isEdited,
    @JsonKey(name: 'edited_at') @UtcDateTimeConverter() DateTime? editedAt,
    @JsonKey(name: 'rich_text_delta') List<dynamic>? richTextDelta,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  /// Realtime payloads often contain nested `Map<dynamic, dynamic>` values
  /// and loose scalars. Parsing those through generated `fromJson` throws and
  /// the message is dropped until a full reload.
  static ChatMessage? tryParseRecord(Map<dynamic, dynamic> raw) {
    try {
      final normalized = _normalizeRecord(raw);
      final id = normalized['id']?.toString();
      final senderId = normalized['sender_id']?.toString();
      if (id == null || id.isEmpty || senderId == null || senderId.isEmpty) {
        return null;
      }
      normalized['id'] = id;
      normalized['sender_id'] = senderId;
      final receiverId = normalized['receiver_id']?.toString();
      normalized['receiver_id'] =
          (receiverId == null || receiverId.isEmpty) ? null : receiverId;
      normalized['sender_name'] = normalized['sender_name']?.toString() ?? '';
      normalized['sender_role'] = normalized['sender_role']?.toString() ?? '';
      normalized['content'] = normalized['content']?.toString() ?? '';

      final created = normalized['created_at'];
      if (created is DateTime) {
        normalized['created_at'] = created.toUtc().toIso8601String();
      } else if (created != null) {
        final parsed = DateTime.tryParse(created.toString());
        if (parsed == null) return null;
        normalized['created_at'] = parsed.toUtc().toIso8601String();
      } else {
        return null;
      }

      final edited = normalized['edited_at'];
      if (edited is DateTime) {
        normalized['edited_at'] = edited.toUtc().toIso8601String();
      } else if (edited != null && edited.toString().isNotEmpty) {
        normalized['edited_at'] =
            DateTime.tryParse(edited.toString())?.toUtc().toIso8601String();
      } else {
        normalized['edited_at'] = null;
      }

      for (final key in ['is_deleted', 'is_forwarded', 'is_edited']) {
        normalized[key] = _asBool(normalized[key]);
      }
      if (normalized['reactions'] is! List) {
        normalized['reactions'] = <dynamic>[];
      }
      if (normalized['rich_text_delta'] is! List) {
        normalized['rich_text_delta'] = null;
      }
      return ChatMessage.fromJson(normalized);
    } catch (_) {
      return null;
    }
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      return v == 'true' || v == 't' || v == '1';
    }
    return false;
  }

  static Map<String, dynamic> _normalizeRecord(Map raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      out[key.toString()] = _normalizeValue(value);
    });
    return out;
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Map) {
      final nested = <String, dynamic>{};
      value.forEach((key, nestedValue) {
        nested[key.toString()] = _normalizeValue(nestedValue);
      });
      return nested;
    }
    if (value is List) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }
}
