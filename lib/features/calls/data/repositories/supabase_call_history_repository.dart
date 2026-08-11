import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/call_history_item.dart';
import 'call_history_repository.dart';
import '../../../../core/logging/app_logger.dart';

class SupabaseCallHistoryRepository implements CallHistoryRepository {
  final SupabaseClient _client;
  final String _currentUserId;

  SupabaseCallHistoryRepository(this._client, this._currentUserId);

  @override
  Future<List<CallHistoryItem>> loadHistory() async {
    try {
      // 1. Find call IDs where current user is a participant
      final partResp = await _client
          .from('call_history_participants')
          .select('call_id')
          .eq('agent_id', _currentUserId);
          
      final Set<String> participantCallIds = (partResp as List).map((p) => p['call_id'].toString()).toSet();

      // 2. Fetch calls where caller or receiver is current user
      final callsResp = await _client
          .from('call_history')
          .select()
          .or('caller_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
          .order('started_at', ascending: false);

      final List<Map<String, dynamic>> rawCalls = List<Map<String, dynamic>>.from(callsResp);
      
      // 3. If there are participantCallIds, fetch those calls too if not already fetched
      if (participantCallIds.isNotEmpty) {
        final existingIds = rawCalls.map((c) => c['id'].toString()).toSet();
        final missingIds = participantCallIds.difference(existingIds);
        
        if (missingIds.isNotEmpty) {
          final missingCallsResp = await _client
              .from('call_history')
              .select()
              .inFilter('id', missingIds.toList());
          rawCalls.addAll(List<Map<String, dynamic>>.from(missingCallsResp));
        }
      }

      if (rawCalls.isEmpty) return [];

      // Sort combined list by started_at DESC
      rawCalls.sort((a, b) {
        final dateA = DateTime.parse(a['started_at'] as String);
        final dateB = DateTime.parse(b['started_at'] as String);
        return dateB.compareTo(dateA);
      });

      // Gather all unique agent IDs and call IDs needed
      final allCallIds = rawCalls.map((c) => c['id'].toString()).toList();
      
      // 4. Fetch all participants for these calls
      final allParticipantsResp = await _client
          .from('call_history_participants')
          .select()
          .inFilter('call_id', allCallIds);
          
      final List<Map<String, dynamic>> rawParticipants = List<Map<String, dynamic>>.from(allParticipantsResp);

      final Set<String> agentIdsToFetch = {};
      for (final call in rawCalls) {
        agentIdsToFetch.add(call['caller_id'].toString());
        agentIdsToFetch.add(call['receiver_id'].toString());
      }
      for (final p in rawParticipants) {
        agentIdsToFetch.add(p['agent_id'].toString());
      }

      // 5. Fetch agents safely
      final agentsResp = await _client
          .from('agents')
          .select('id, full_name, username, avatar_url')
          .inFilter('id', agentIdsToFetch.toList());
          
      final Map<String, Map<String, dynamic>> agentsMap = {};
      for (final a in agentsResp as List) {
        agentsMap[a['id'].toString()] = a as Map<String, dynamic>;
      }

      // 6. Construct CallHistoryItems
      final List<CallHistoryItem> result = [];

      for (final call in rawCalls) {
        final callId = call['id'].toString();
        
        // Caller info
        final callerId = call['caller_id'].toString();
        final callerAgent = agentsMap[callerId];
        final callerName = callerAgent?['full_name'] ?? callerAgent?['username'] ?? 'Unknown Caller';
        
        // Receiver info
        final receiverId = call['receiver_id'].toString();
        final receiverAgent = agentsMap[receiverId];
        final receiverName = receiverAgent?['full_name'] ?? receiverAgent?['username'] ?? 'Unknown Receiver';

        final direction = _parseDirection(call['direction'] as String?);
        
        String? avatarUrl;
        if (direction == CallDirection.outgoing) {
          avatarUrl = receiverAgent?['avatar_url']?.toString();
        } else {
          avatarUrl = callerAgent?['avatar_url']?.toString();
        }

        final callType = _parseType(call['type'] as String?);
        final status = _parseStatus(call['status'] as String?);
        
        Duration? duration;
        if (call['duration_seconds'] != null) {
          duration = Duration(seconds: call['duration_seconds'] as int);
        }

        // Participants mapping
        final callParticipantsData = rawParticipants.where((p) => p['call_id'].toString() == callId).toList();
        final List<CallParticipant> callParticipants = [];
        
        for (final pData in callParticipantsData) {
          final pAgentId = pData['agent_id'].toString();
          final pAgent = agentsMap[pAgentId];
          final pName = pAgent?['full_name'] ?? pAgent?['username'] ?? 'Unknown Agent';
          final pRole = (pData['participant_role'] == 'caller') ? CallParticipantRole.caller : CallParticipantRole.participant;
          
          DateTime? joinedAt;
          if (pData['joined_at'] != null) joinedAt = DateTime.parse(pData['joined_at'] as String);
          
          DateTime? leftAt;
          if (pData['left_at'] != null) leftAt = DateTime.parse(pData['left_at'] as String);

          callParticipants.add(CallParticipant(
            id: pData['id'].toString(),
            agentId: pAgentId,
            agentName: pName,
            role: pRole,
            joinedAt: joinedAt,
            leftAt: leftAt,
            avatarUrl: pAgent?['avatar_url']?.toString(),
          ));
        }

        result.add(CallHistoryItem(
          id: callId,
          callerId: callerId,
          callerName: callerName,
          receiverId: receiverId,
          receiverName: receiverName,
          avatarUrl: avatarUrl,
          startedAt: DateTime.parse(call['started_at'] as String),
          endedAt: call['ended_at'] != null ? DateTime.parse(call['ended_at'] as String) : null,
          duration: duration,
          callType: callType,
          direction: direction,
          status: status,
          participants: callParticipants,
        ));
      }

      return result;
    } catch (e, stackTrace) {
      appLogger.error('Failed to load call history', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  @override
  Stream<List<CallHistoryItem>> watchHistory() {
    final controller = StreamController<List<CallHistoryItem>>.broadcast();
    RealtimeChannel? channel;
    
    Future<void> fetchAndEmit() async {
      try {
        final data = await loadHistory();
        if (!controller.isClosed) {
          controller.add(data);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller.onListen = () {
      fetchAndEmit();

      channel = _client.channel('public:call_history_realtime_$_currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'call_history',
          callback: (payload) {
            fetchAndEmit();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'call_history_participants',
          callback: (payload) {
            fetchAndEmit();
          },
        );
        
      channel?.subscribe();
    };

    controller.onCancel = () {
      if (channel != null) {
        _client.removeChannel(channel!);
      }
    };

    return controller.stream;
  }

  @override
  Future<String?> logCall({
    required String callerId,
    required String receiverId,
    required CallType type,
    required CallDirection direction,
    required List<String> participantIds,
  }) async {
    try {
      final response = await _client.from('call_history').insert({
        'caller_id': callerId,
        'receiver_id': receiverId,
        'status': 'initiated',
        'type': type == CallType.video ? 'video' : 'audio',
        'direction': direction == CallDirection.incoming ? 'incoming' : 'outgoing',
      }).select('id').single();

      final callId = response['id'] as String;

      if (participantIds.isNotEmpty) {
        final participantRows = participantIds.map((pId) => {
          'call_id': callId,
          'agent_id': pId,
          'participant_role': pId == callerId ? 'caller' : 'participant',
        }).toList();

        await _client.from('call_history_participants').insert(participantRows);
      }

      return callId;
    } catch (e, stackTrace) {
      appLogger.error('Failed to log call', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    DateTime? endedAt,
    int? durationSeconds,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': _statusToString(status),
      };
      if (endedAt != null) {
        updates['ended_at'] = endedAt.toIso8601String();
      }
      if (durationSeconds != null) {
        updates['duration_seconds'] = durationSeconds;
      }
      await _client.from('call_history').update(updates).eq('id', callId);
    } catch (e, stackTrace) {
      appLogger.error('Failed to update call status', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> addParticipants({
    required String callId,
    required List<String> agentIds,
  }) async {
    if (agentIds.isEmpty) return;
    try {
      final inserts = agentIds.map((id) => {
        'call_id': callId,
        'agent_id': id,
        'participant_role': 'participant',
      }).toList();
      
      for (final insertData in inserts) {
        try {
          await _client.from('call_history_participants').insert(insertData);
        } catch (e) {
          appLogger.warning('Could not insert participant (might already exist)', context: {'callId': callId, 'agentId': insertData['agent_id']});
        }
      }
    } catch (e, stackTrace) {
      appLogger.error('Failed to add participants', error: e, stackTrace: stackTrace);
    }
  }

  CallDirection _parseDirection(String? dir) {
    if (dir == 'incoming') return CallDirection.incoming;
    return CallDirection.outgoing;
  }

  CallType _parseType(String? type) {
    if (type == 'video') return CallType.video;
    return CallType.audio;
  }

  CallStatus _parseStatus(String? status) {
    switch (status) {
      case 'initiated': return CallStatus.initiated;
      case 'ringing': return CallStatus.ringing;
      case 'answered': return CallStatus.answered;
      case 'missed': return CallStatus.missed;
      case 'rejected': return CallStatus.rejected;
      case 'cancelled': return CallStatus.cancelled;
      case 'ended': return CallStatus.ended;
      default:
        appLogger.warning('Unknown call status encountered: $status');
        return CallStatus.ended;
    }
  }

  String _statusToString(CallStatus status) {
    return status.name;
  }
}
