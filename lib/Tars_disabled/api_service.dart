import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRetryable;

  const ApiException({
    required this.message,
    this.statusCode,
    this.isRetryable = false,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String baseUrl;
  final int maxRetries;
  final Duration retryDelay;
  final Duration requestTimeout;

  ApiService({
    required this.baseUrl,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 30),
  });

  Future<String> askQuestion(AskRequest request) async {
    final url = Uri.parse('$baseUrl/ask');

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final isLastAttempt = attempt == maxRetries - 1;
      try {
        final response = await http
            .post(
              url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(request.toJson()),
            )
            .timeout(const Duration(seconds: 100));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['answer'] ?? "No answer returned";
        }

        final isRetryable = response.statusCode >= 500;
        final detail =
            _extractErrorDetail(response.body) ??
            'Failed to get answer: ${response.statusCode}';

        if (!isRetryable || isLastAttempt) {
          throw ApiException(
            message: detail,
            statusCode: response.statusCode,
            isRetryable: isRetryable,
          );
        }
      } on TimeoutException {
        if (isLastAttempt) {
          throw const ApiException(
            message:
                '⏳ The AI is still thinking and took too long to reply. Please try again in a moment.',
            isRetryable: true,
          );
        }
      } on Exception catch (e) {
        if (isLastAttempt) {
          throw ApiException(
            message: 'Failed to connect to backend: $e',
            isRetryable: true,
          );
        }
      }

      final delay = retryDelay * (attempt + 1);
      await Future.delayed(delay);
    }

    throw const ApiException(
      message: 'Cloud backend is unreachable after multiple attempts.',
      isRetryable: true,
    );
  }

  String? _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail != null) return detail.toString();
        final message = decoded['message'];
        if (message != null) return message.toString();
      }
    } catch (_) {
      // Ignore parsing issues; fall back to raw body
    }
    if (body.isNotEmpty) return body;
    return null;
  }
}
