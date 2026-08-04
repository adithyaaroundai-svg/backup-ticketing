import 'dart:convert';
import 'package:hive/hive.dart';
import '../../domain/entities/chat_message.dart';

class HiveChatMessage {
  final String id;
  final String senderId;
  final String? receiverId;
  final String senderName;
  final String senderRole;
  final String? senderAvatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isDeleted;
  final String reactionsJson;
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToContent;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final String channel;
  final String? richTextDeltaJson;

  HiveChatMessage({
    required this.id,
    required this.senderId,
    this.receiverId,
    required this.senderName,
    required this.senderRole,
    this.senderAvatarUrl,
    required this.content,
    required this.createdAt,
    required this.isDeleted,
    required this.reactionsJson,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToContent,
    this.fileUrl,
    this.fileName,
    this.fileType,
    required this.channel,
    this.richTextDeltaJson,
  });

  factory HiveChatMessage.fromMessage(ChatMessage msg) {
    return HiveChatMessage(
      id: msg.id,
      senderId: msg.senderId,
      receiverId: msg.receiverId,
      senderName: msg.senderName,
      senderRole: msg.senderRole,
      senderAvatarUrl: msg.senderAvatarUrl,
      content: msg.content,
      createdAt: msg.createdAt.toUtc(),
      isDeleted: msg.isDeleted,
      reactionsJson: jsonEncode(msg.reactions),
      replyToMessageId: msg.replyToMessageId,
      replyToSenderName: msg.replyToSenderName,
      replyToContent: msg.replyToContent,
      fileUrl: msg.fileUrl,
      fileName: msg.fileName,
      fileType: msg.fileType,
      channel: msg.channel,
      richTextDeltaJson: msg.richTextDelta != null ? jsonEncode(msg.richTextDelta) : null,
    );
  }

  ChatMessage toMessage() {
    List<Map<String, dynamic>> decodedReactions = [];
    try {
      final List<dynamic> list = jsonDecode(reactionsJson);
      decodedReactions = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      // ignore parsing errors
    }

    List<dynamic>? decodedRichTextDelta;
    if (richTextDeltaJson != null) {
      try {
        decodedRichTextDelta = jsonDecode(richTextDeltaJson!);
      } catch (e) {
        // ignore parsing errors
      }
    }

    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName,
      senderRole: senderRole,
      senderAvatarUrl: senderAvatarUrl,
      content: content,
      createdAt: createdAt,
      isDeleted: isDeleted,
      reactions: decodedReactions,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      channel: channel,
      richTextDelta: decodedRichTextDelta,
    );
  }
}

class HiveChatMessageAdapter extends TypeAdapter<HiveChatMessage> {
  @override
  final int typeId = 0;

  @override
  HiveChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveChatMessage(
      id: fields[0] as String,
      senderId: fields[1] as String,
      receiverId: fields[2] as String?,
      senderName: fields[3] as String,
      senderRole: fields[4] as String,
      senderAvatarUrl: fields[5] as String?,
      content: fields[6] as String,
      createdAt: fields[7] as DateTime,
      isDeleted: fields[8] as bool,
      reactionsJson: fields[9] as String,
      replyToMessageId: fields[10] as String?,
      replyToSenderName: fields[11] as String?,
      replyToContent: fields[12] as String?,
      fileUrl: fields[13] as String?,
      fileName: fields[14] as String?,
      fileType: fields[15] as String?,
      channel: fields[16] as String,
      richTextDeltaJson: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveChatMessage obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderId)
      ..writeByte(2)
      ..write(obj.receiverId)
      ..writeByte(3)
      ..write(obj.senderName)
      ..writeByte(4)
      ..write(obj.senderRole)
      ..writeByte(5)
      ..write(obj.senderAvatarUrl)
      ..writeByte(6)
      ..write(obj.content)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isDeleted)
      ..writeByte(9)
      ..write(obj.reactionsJson)
      ..writeByte(10)
      ..write(obj.replyToMessageId)
      ..writeByte(11)
      ..write(obj.replyToSenderName)
      ..writeByte(12)
      ..write(obj.replyToContent)
      ..writeByte(13)
      ..write(obj.fileUrl)
      ..writeByte(14)
      ..write(obj.fileName)
      ..writeByte(15)
      ..write(obj.fileType)
      ..writeByte(16)
      ..write(obj.channel)
      ..writeByte(17)
      ..write(obj.richTextDeltaJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
