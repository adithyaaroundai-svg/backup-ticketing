import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_exception.dart';

/// Default base URL matches the Node server's `/api` mount point when run
/// locally. Override at build/run time with:
///   --dart-define=API_BASE_URL=http://localhost:3000/api
const String _defaultBaseUrl = 'http://localhost:3000/api';

/// A single file to attach to a multipart request. Bytes are used (rather
/// than a file path) so this works uniformly on web and native platforms.
class UploadPart {
  final String field;
  final String filename;
  final List<int> bytes;

  UploadPart({required this.field, required this.filename, required this.bytes});
}

/// Thin wrapper around [http.Client] that:
/// - prefixes every request with the configured base URL
/// - attaches the bearer token (via a getter, so it always reads the
///   latest value from [AuthProvider] without a circular dependency)
/// - decodes JSON responses and throws [ApiException] on failure
class ApiClient {
  final String baseUrl;
  final String? Function() tokenGetter;
  final http.Client _client;

  ApiClient({String? baseUrl, required this.tokenGetter, http.Client? client})
      : baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl),
        _client = client ?? http.Client();

  String? get token => tokenGetter();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final full = path.startsWith('http') ? path : '$baseUrl$path';
    final uri = Uri.parse(full);
    if (query == null || query.isEmpty) return uri;
    final qp = Map<String, String>.from(uri.queryParameters);
    query.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });
    return uri.replace(queryParameters: qp);
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    h['Accept'] = 'application/json';
    final t = token;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  dynamic _decode(http.Response resp) {
    dynamic body;
    try {
      body = resp.body.isEmpty ? null : jsonDecode(resp.body);
    } catch (_) {
      body = null;
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body;
    }
    String message = 'Request failed (${resp.statusCode}).';
    if (body is Map && body['error'] is String) {
      message = body['error'] as String;
    }
    throw ApiException(resp.statusCode, message);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final resp = await _client.get(_uri(path, query), headers: _headers());
      return _decode(resp);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Network error: $e');
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final resp = await _client.post(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      );
      return _decode(resp);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Network error: $e');
    }
  }

  /// Multipart POST. [fields] are single-value form fields; [repeatedFields]
  /// allows the same field name to appear more than once (e.g.
  /// `assignee_ids`, `remove_file_ids`); [fileParts] are actual file
  /// uploads.
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<MapEntry<String, String>> repeatedFields = const [],
    List<UploadPart> fileParts = const [],
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers(json: false));
      fields.forEach((k, v) {
        request.files.add(http.MultipartFile.fromString(k, v));
      });
      for (final entry in repeatedFields) {
        request.files.add(http.MultipartFile.fromString(entry.key, entry.value));
      }
      for (final part in fileParts) {
        request.files.add(http.MultipartFile.fromBytes(
          part.field,
          part.bytes,
          filename: part.filename,
        ));
      }
      final streamed = await _client.send(request);
      final resp = await http.Response.fromStream(streamed);
      return _decode(resp);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Network error: $e');
    }
  }

  /// Download URL for a file in Supabase Storage.
  String fileDownloadUrl(String storagePath) => Supabase.instance.client.storage.from('dev_crm_files').getPublicUrl(storagePath);

  /// Download URL for a task file in Supabase Storage.
  String taskFileDownloadUrl(String storagePath) => Supabase.instance.client.storage.from('dev_crm_files').getPublicUrl(storagePath);
}
