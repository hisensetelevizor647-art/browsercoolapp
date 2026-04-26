import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'model_catalog.dart';

class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => <String, String>{
    'role': role,
    'content': content,
  };
}

class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> complete({
    required AiModel model,
    required List<AiChatMessage> messages,
  }) async {
    if (AppConfig.nvidiaApiKey.trim().isEmpty) {
      throw Exception(
        'NVIDIA_API_KEY is empty. Run with --dart-define=NVIDIA_API_KEY=your_key',
      );
    }

    final Uri endpoint = _resolveEndpoint();
    final Map<String, dynamic> payload = <String, dynamic>{
      'model': model.remoteModel,
      'messages': messages.map((AiChatMessage m) => m.toJson()).toList(),
      'temperature': model.temperature,
      'top_p': model.topP,
      'max_tokens': model.maxTokens,
      'stream': false,
      if (model.extraBody.isNotEmpty) ...model.extraBody,
    };

    final http.Response response = await _client.post(
      endpoint,
      headers: <String, String>{
        'Authorization': 'Bearer ${AppConfig.nvidiaApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final String responseText = response.body;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(response.statusCode, responseText));
    }

    final dynamic decoded = jsonDecode(responseText);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid AI response format.');
    }

    final dynamic choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('AI response did not include choices.');
    }

    final dynamic first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('AI response choice format is invalid.');
    }

    final dynamic message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw Exception('AI response message is missing.');
    }

    final dynamic content = message['content'];
    final String normalized = _normalizeContent(content);
    if (normalized.trim().isEmpty) {
      throw Exception('AI returned an empty answer.');
    }

    return normalized;
  }

  void dispose() {
    _client.close();
  }

  Uri _resolveEndpoint() {
    final String base = AppConfig.nvidiaBaseUrl.trim();
    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$normalized/chat/completions');
  }

  String _extractError(int statusCode, String responseText) {
    try {
      final dynamic decoded = jsonDecode(responseText);
      if (decoded is Map<String, dynamic>) {
        final dynamic error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final dynamic message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return 'AI request failed ($statusCode): $message';
          }
        }
      }
    } catch (_) {
      // Keep fallback below.
    }
    return 'AI request failed with status $statusCode.';
  }

  String _normalizeContent(dynamic content) {
    if (content is String) {
      return content;
    }

    if (content is List) {
      final StringBuffer text = StringBuffer();
      for (final dynamic item in content) {
        if (item is Map<String, dynamic>) {
          final dynamic part = item['text'];
          if (part is String) {
            text.write(part);
          }
        }
      }
      return text.toString();
    }

    return content?.toString() ?? '';
  }
}
