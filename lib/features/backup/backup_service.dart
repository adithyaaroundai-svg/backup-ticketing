import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backup_service_native.dart'
    if (dart.library.html) 'backup_service_web_stub.dart' as native_save;
import 'backup_web_download.dart'
    if (dart.library.io) 'backup_web_download_stub.dart' as web_download;
import 'google_drive_backup_service.dart';

/// Result returned after a backup completes or fails.
class BackupResult {
  final bool success;
  final String? filePath;
  final String? error;
  final Map<String, dynamic>? stats;

  const BackupResult.success(this.filePath, {this.stats})
      : success = true,
        error = null;

  const BackupResult.failure(this.error)
      : success = false,
        filePath = null,
        stats = null;
}

/// Key used to persist the last backup timestamp in SharedPreferences.
const _kLastBackupKey = 'backup.last_backup_at';

/// Reads the last backup timestamp from local storage.
Future<DateTime?> getLastBackupTime() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kLastBackupKey);
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

/// Saves the current time as the last backup timestamp.
Future<void> _saveLastBackupTime() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLastBackupKey, DateTime.now().toIso8601String());
}

/// Helper to safely fetch all table data with automatic pagination (bypassing PostgREST 1000 row limit).
Future<List<Map<String, dynamic>>> _fetchAllRows(
  SupabaseClient client,
  String table, {
  String? schema,
  String? orderBy,
  bool ascending = true,
  Map<String, dynamic>? equalsFilter,
  String label = '',
}) async {
  final allRows = <Map<String, dynamic>>[];
  const int pageSize = 1000;
  int from = 0;

  try {
    while (true) {
      dynamic query = schema != null
          ? client.schema(schema).from(table).select()
          : client.from(table).select();

      if (equalsFilter != null) {
        equalsFilter.forEach((k, v) {
          query = query.eq(k, v);
        });
      }

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      final res = await query.range(from, from + pageSize - 1);
      if (res is List && res.isNotEmpty) {
        final rows = List<Map<String, dynamic>>.from(
          res.map((item) => Map<String, dynamic>.from(item as Map)),
        );
        allRows.addAll(rows);

        if (rows.length < pageSize) {
          break; // Last page reached
        }
        from += pageSize;
      } else {
        break;
      }
    }
    return allRows;
  } catch (e) {
    debugPrint('Backup: Notice - could not fetch $label: $e');
    return allRows;
  }
}

/// Helper to categorize file into subfolder based on extension / MIME.
String _getMediaCategory(String fileName, String? mimeType) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext) ||
      (mimeType?.startsWith('image/') ?? false)) {
    return 'images';
  }
  if (['mp4', 'mov', 'webm', 'avi', 'mkv', 'flv', '3gp'].contains(ext) ||
      (mimeType?.startsWith('video/') ?? false)) {
    return 'videos';
  }
  if (['mp3', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'weba'].contains(ext) ||
      (mimeType?.startsWith('audio/') ?? false)) {
    return 'audio';
  }
  if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'zip'].contains(ext) ||
      (mimeType?.contains('pdf') ?? false) ||
      (mimeType?.contains('document') ?? false)) {
    return 'documents';
  }
  return 'others';
}

/// Sanitizes a file name for zip archive paths.
String _sanitizeFileName(String name) {
  return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

/// Fetches and packages all database tables and media into an in-memory ZIP archive.
Future<({Archive archive, Map<String, dynamic> backupInfo})> _buildBackupArchive({
  required String agentId,
  required String agentName,
  required String agentRole,
  required bool includeMedia,
  void Function(String progressStatus)? onProgress,
}) async {
  final client = Supabase.instance.client;
  final archive = Archive();

  void addJsonFile(String name, dynamic data) {
    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    archive.addFile(ArchiveFile(name, jsonBytes.length, jsonBytes));
  }

  // ── 1. Core CRM Data ────────────────────────────────────────────────────
  onProgress?.call('Fetching tickets...');
  final ticketsRaw = await _fetchAllRows(
    client,
    'tickets',
    orderBy: 'created_at',
    ascending: false,
    label: 'tickets',
  );

  onProgress?.call('Fetching customers (${ticketsRaw.length} tickets found)...');
  final customersRaw = await _fetchAllRows(
    client,
    'customers',
    orderBy: 'company_name',
    ascending: true,
    label: 'customers',
  );

  onProgress?.call('Fetching ticket comments & remarks...');
  final ticketCommentsRaw = await _fetchAllRows(
    client,
    'ticket_comments',
    orderBy: 'created_at',
    ascending: true,
    label: 'ticket_comments',
  );

  final ticketRemarksRaw = await _fetchAllRows(
    client,
    'ticket_remarks',
    orderBy: 'created_at',
    ascending: true,
    label: 'ticket_remarks',
  );

  // ── 2. Sales & Pipelines ────────────────────────────────────────────────
  onProgress?.call('Fetching pipelines & deals...');

  final leadsGlobalRaw = await _fetchAllRows(
    client,
    'leads',
    equalsFilter: {'pipeline_type': 'global'},
    orderBy: 'created_at',
    ascending: false,
    label: 'leads (global pipeline)',
  );

  final leadsPrivateRaw = await _fetchAllRows(
    client,
    'leads',
    equalsFilter: {'pipeline_type': 'private'},
    orderBy: 'created_at',
    ascending: false,
    label: 'leads (private pipeline)',
  );

  final dealsRaw = await _fetchAllRows(
    client,
    'deals',
    orderBy: 'created_at',
    ascending: false,
    label: 'deals (sales pipeline)',
  );

  final proposalsRaw = await _fetchAllRows(
    client,
    'history',
    orderBy: 'created_at',
    ascending: false,
    label: 'proposals history',
  );

  // ── 3. Chat Messages ────────────────────────────────────────────────────
  onProgress?.call('Fetching complete chat history...');

  final allChatRaw = await _fetchAllRows(
    client,
    'chat_messages',
    orderBy: 'created_at',
    ascending: true,
    label: 'chat_messages',
  );

  // Split into global, DMs, and channel chats for easy consumption
  final globalChat = allChatRaw.where((m) => m['receiver_id'] == null && (m['channel'] == null || m['channel'] == 'support-chat')).toList();
  final dmChat = allChatRaw.where((m) => m['receiver_id'] != null).toList();
  final channelChat = allChatRaw.where((m) => m['channel'] != null && m['channel'] != 'support-chat').toList();

  // ── 4. Developer CRM ────────────────────────────────────────────────────
  onProgress?.call('Fetching Developer CRM tasks & projects...');

  final devTasksRaw = await _fetchAllRows(
    client,
    'tasks',
    schema: 'aroundtally',
    orderBy: 'created_at',
    ascending: false,
    label: 'dev_tasks',
  );

  final devWorkItemsRaw = await _fetchAllRows(
    client,
    'work_items',
    schema: 'aroundtally',
    orderBy: 'created_at',
    ascending: false,
    label: 'dev_work_items',
  );

  final devClientsRaw = await _fetchAllRows(
    client,
    'clients',
    schema: 'aroundtally',
    label: 'dev_clients',
  );

  final devTaskNotesRaw = await _fetchAllRows(
    client,
    'task_notes',
    schema: 'aroundtally',
    label: 'dev_task_notes',
  );

  final devAdvancesRaw = await _fetchAllRows(
    client,
    'advances',
    schema: 'aroundtally',
    label: 'dev_advances',
  );

  final devActivityLogRaw = await _fetchAllRows(
    client,
    'activity_log',
    schema: 'aroundtally',
    orderBy: 'created_at',
    ascending: false,
    label: 'dev_activity_log',
  );

  // ── 5. Productivity & Notifications ────────────────────────────────────
  final notificationsRaw = await _fetchAllRows(
    client,
    'notifications',
    orderBy: 'created_at',
    ascending: false,
    label: 'notifications',
  );

  // ── 6. Download and package Media Files if enabled ──────────────────────
  int mediaDownloadedCount = 0;
  int mediaFailedCount = 0;
  final mediaList = <Map<String, String>>[];

  if (includeMedia) {
    onProgress?.call('Scanning media attachments (images, videos, voice notes)...');

    // Collect all media items with valid HTTP URLs
    final mediaToDownload = <Map<String, String>>[];

    // 1. Chat attachments (images, videos, documents)
    for (final m in allChatRaw) {
      final fileUrl = m['file_url']?.toString();
      final fileName = m['file_name']?.toString() ?? 'attachment_${m['id']}';
      final fileType = m['file_type']?.toString();
      if (fileUrl != null && fileUrl.startsWith('http')) {
        mediaToDownload.add({
          'url': fileUrl,
          'name': fileName,
          'type': fileType ?? '',
          'source': 'chat',
          'id': m['id']?.toString() ?? '',
        });
      }
    }

    // 2. Ticket voice notes & audio
    for (final r in ticketRemarksRaw) {
      final voiceUrl = r['voice_url']?.toString();
      if (voiceUrl != null && voiceUrl.startsWith('http')) {
        final id = r['id']?.toString() ?? 'remark';
        mediaToDownload.add({
          'url': voiceUrl,
          'name': 'voice_note_$id.wav',
          'type': 'audio/wav',
          'source': 'ticket_remarks',
          'id': id,
        });
      }
    }

    // 3. Proposal PDFs
    for (final p in proposalsRaw) {
      final fileUrl = p['file_url']?.toString() ?? p['pdf_url']?.toString();
      if (fileUrl != null && fileUrl.startsWith('http')) {
        final id = p['id']?.toString() ?? 'proposal';
        mediaToDownload.add({
          'url': fileUrl,
          'name': 'proposal_$id.pdf',
          'type': 'application/pdf',
          'source': 'proposals',
          'id': id,
        });
      }
    }

    final httpClient = http.Client();
    final totalMedia = mediaToDownload.length;
    final batchSize = 4;

    for (int i = 0; i < mediaToDownload.length; i += batchSize) {
      final end = (i + batchSize < mediaToDownload.length) ? i + batchSize : mediaToDownload.length;
      final batch = mediaToDownload.sublist(i, end);

      onProgress?.call('Downloading media (${i + 1}-$end/$totalMedia)...');
      // Yield to let Flutter Web repaint UI
      await Future.delayed(const Duration(milliseconds: 20));

      await Future.wait(batch.map((item) async {
        final url = item['url']!;
        final rawName = item['name']!;
        final category = _getMediaCategory(rawName, item['type']);
        final safeName = _sanitizeFileName('${item['id']}_$rawName');
        final zipPath = 'media/$category/$safeName';

        try {
          final response = await httpClient
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            // Skip single files larger than 4MB on web to prevent browser memory exhaustion
            if (response.bodyBytes.length <= 4 * 1024 * 1024) {
              archive.addFile(
                ArchiveFile(
                  zipPath,
                  response.bodyBytes.length,
                  response.bodyBytes,
                ),
              );

              mediaDownloadedCount++;
              mediaList.add({
                'source': item['source'] ?? '',
                'category': category,
                'filename': safeName,
                'size_bytes': response.bodyBytes.length.toString(),
                'original_url': url,
              });
            } else {
              debugPrint('Notice: skipped media file > 4MB: $rawName');
              mediaFailedCount++;
            }
          } else {
            mediaFailedCount++;
          }
        } catch (e) {
          debugPrint('Notice: skipped media download ($url): $e');
          mediaFailedCount++;
        }
      }));
    }
    httpClient.close();
  }

  // ── 7. Build Metadata & Add JSON Files ───────────────────────────────────
  onProgress?.call('Packaging database tables into archive...');
  await Future.delayed(const Duration(milliseconds: 30));

  final backupInfo = {
    'backup_created_at': DateTime.now().toIso8601String(),
    'agent_id': agentId,
    'agent_name': agentName,
    'agent_role': agentRole,
    'app_version': '1.0.0',
    'includes_media': includeMedia,
    'counts': {
      'tickets': ticketsRaw.length,
      'customers': customersRaw.length,
      'ticket_comments': ticketCommentsRaw.length,
      'ticket_remarks': ticketRemarksRaw.length,
      'leads_global_pipeline': leadsGlobalRaw.length,
      'leads_private_pipeline': leadsPrivateRaw.length,
      'deals_sales_pipeline': dealsRaw.length,
      'proposals': proposalsRaw.length,
      'chat_messages_total': allChatRaw.length,
      'global_chat_messages': globalChat.length,
      'dm_messages': dmChat.length,
      'channel_messages': channelChat.length,
      'dev_crm_tasks': devTasksRaw.length,
      'dev_crm_work_items': devWorkItemsRaw.length,
      'dev_crm_clients': devClientsRaw.length,
      'notifications': notificationsRaw.length,
      'media_files_downloaded': mediaDownloadedCount,
      'media_files_failed': mediaFailedCount,
    },
  };

  addJsonFile('backup_info.json', backupInfo);
  addJsonFile('tickets.json', ticketsRaw);
  addJsonFile('customers.json', customersRaw);
  addJsonFile('ticket_comments.json', ticketCommentsRaw);
  addJsonFile('ticket_remarks.json', ticketRemarksRaw);
  addJsonFile('leads_global_pipeline.json', leadsGlobalRaw);
  addJsonFile('leads_private_pipeline.json', leadsPrivateRaw);
  addJsonFile('deals_sales_pipeline.json', dealsRaw);
  addJsonFile('proposals.json', proposalsRaw);
  addJsonFile('all_chat_messages.json', allChatRaw);
  addJsonFile('global_chat.json', globalChat);
  addJsonFile('dm_messages.json', dmChat);
  addJsonFile('channel_messages.json', channelChat);

  if (devTasksRaw.isNotEmpty || devWorkItemsRaw.isNotEmpty || devClientsRaw.isNotEmpty) {
    addJsonFile('dev_crm_tasks.json', devTasksRaw);
    addJsonFile('dev_crm_work_items.json', devWorkItemsRaw);
    addJsonFile('dev_crm_clients.json', devClientsRaw);
    addJsonFile('dev_crm_task_notes.json', devTaskNotesRaw);
    addJsonFile('dev_crm_advances.json', devAdvancesRaw);
    addJsonFile('dev_crm_activity_log.json', devActivityLogRaw);
  }

  addJsonFile('notifications.json', notificationsRaw);

  if (includeMedia && mediaList.isNotEmpty) {
    addJsonFile('media_manifest.json', mediaList);
  }

  return (archive: archive, backupInfo: backupInfo);
}

/// Main local backup entry point.
Future<BackupResult> createLocalBackup({
  required String agentId,
  required String agentName,
  required String agentRole,
  bool includeMedia = true,
  void Function(String progressStatus)? onProgress,
}) async {
  try {
    final backup = await _buildBackupArchive(
      agentId: agentId,
      agentName: agentName,
      agentRole: agentRole,
      includeMedia: includeMedia,
      onProgress: onProgress,
    );

    onProgress?.call('Generating ZIP archive...');
    await Future.delayed(const Duration(milliseconds: 50));
    final zipBytes = ZipEncoder().encode(backup.archive, level: 0);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'tallyCare_full_backup_$timestamp.zip';

    String savedPath;
    if (kIsWeb) {
      web_download.triggerDownload(zipBytes, fileName);
      savedPath = 'Your browser Downloads folder ($fileName)';
    } else {
      savedPath = await native_save.saveZipToDownloads(zipBytes, fileName);
    }

    await _saveLastBackupTime();
    return BackupResult.success(savedPath, stats: backup.backupInfo);
  } catch (e) {
    return BackupResult.failure(e.toString());
  }
}

/// Backs up all CRM database data + media and uploads directly to Google Drive.
Future<BackupResult> createGoogleDriveBackup({
  required String agentId,
  required String agentName,
  required String agentRole,
  bool includeMedia = true,
  void Function(String progressStatus)? onProgress,
}) async {
  try {
    final backup = await _buildBackupArchive(
      agentId: agentId,
      agentName: agentName,
      agentRole: agentRole,
      includeMedia: includeMedia,
      onProgress: onProgress,
    );

    onProgress?.call('Generating ZIP archive...');
    await Future.delayed(const Duration(milliseconds: 50));
    final zipBytes = ZipEncoder().encode(backup.archive, level: 0);
    final sizeMb = (zipBytes.length / (1024 * 1024)).toStringAsFixed(2);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'tallyCare_full_backup_$timestamp.zip';

    onProgress?.call('Uploading $sizeMb MB to Google Drive...');
    await Future.delayed(const Duration(milliseconds: 50));

    debugPrint('Starting Google Drive upload for $fileName ($sizeMb MB)...');
    final driveResult = await GoogleDriveBackupService.uploadZipToDrive(
      zipBytes: zipBytes,
      fileName: fileName,
    );
    debugPrint('Google Drive upload completed with success: ${driveResult.success}');

    if (driveResult.success) {
      await _saveLastBackupTime();
      return BackupResult.success(
        'Uploaded to Google Drive (TallyCare Backups/$fileName)',
        stats: backup.backupInfo,
      );
    } else {
      return BackupResult.failure(driveResult.error ?? 'Unknown error uploading to Google Drive');
    }
  } catch (e) {
    return BackupResult.failure(e.toString());
  }
}

/// Riverpod provider that exposes the last backup time reactively.
final lastBackupTimeProvider = FutureProvider<DateTime?>((ref) async {
  return getLastBackupTime();
});

