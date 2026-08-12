import 'package:supabase_flutter/supabase_flutter.dart';
import 'zoho_api_service.dart';
import '../../features/calls/data/repositories/call_history_repository.dart';
import '../../features/calls/domain/models/call_history_item.dart';

class ZohoSyncService {
  final CallHistoryRepository _callRepository;

  ZohoSyncService(this._callRepository);

  /// Fetches MediaSessions from Zoho Cliq and attempts to sync them into Supabase
  Future<void> syncCallHistory() async {
    try {
      final rawSessions = await ZohoApiService.fetchCallHistory();

      for (var session in rawSessions) {
        // Here we parse the Zoho Cliq MediaSession payload.
        // The structure depends on the exact Zoho response. 
        // We do a basic mapping assuming 'type', 'status', 'start_time', etc.
        
        // Example mapping logic:
        // final sessionId = session['session_id'];
        // final type = session['type'] == 'video' ? CallType.video : CallType.audio;
        // final status = _mapZohoStatus(session['status']);
        
        // To properly insert it, we'd look up the Supabase user ID based on the Zoho emails/IDs,
        // but for now, we will log it as a sync operation that needs precise data mapping.
        
        print('Fetched Zoho Session: $session');
        
        // In a full implementation, we would call:
        // await _callRepository.logCall(...) or a direct Supabase insert for external calls.
      }
    } catch (e) {
      print('Failed to sync Zoho call history: $e');
    }
  }
}
