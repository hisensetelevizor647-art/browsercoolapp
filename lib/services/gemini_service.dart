import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'text_cleaner.dart';

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}

class _ModelConfig {
  const _ModelConfig({
    required this.id,
    required this.temperature,
    required this.topP,
    required this.maxTokens,
    this.frequencyPenalty,
    this.presencePenalty,
    this.extraBody = const {},
  });

  final String id;
  final double temperature;
  final double topP;
  final int maxTokens;
  final double? frequencyPenalty;
  final double? presencePenalty;
  final Map<String, Object?> extraBody;
}

class GeminiService with ChangeNotifier {
  static const String apiBaseUrl = String.fromEnvironment(
    'NVIDIA_BASE_URL',
    defaultValue: 'https://integrate.api.nvidia.com/v1',
  );
  static const String apiKey = String.fromEnvironment(
    'NVIDIA_API_KEY',
    defaultValue:
        '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',
  );
  static const int _maxContextMessages = 24;
  static const String autoLanguageInstruction =
      'Always respond in the same language as the latest user message. '
      'If the user mixes languages, prefer the dominant language of the latest message. '
      'Keep responses concise unless the user asks for detail.';
  static const String _fallbackModelId =
      'abacusai/dracarys-llama-3.1-70b-instruct';
  static const Map<String, _ModelConfig> _modelConfigs = {
    'abacusai/dracarys-llama-3.1-70b-instruct': _ModelConfig(
      id: 'abacusai/dracarys-llama-3.1-70b-instruct',
      temperature: 0.5,
      topP: 1.0,
      maxTokens: 1024,
    ),
    'bytedance/seed-oss-36b-instruct': _ModelConfig(
      id: 'bytedance/seed-oss-36b-instruct',
      temperature: 1.1,
      topP: 0.95,
      maxTokens: 4096,
      frequencyPenalty: 0,
      presencePenalty: 0,
      extraBody: {'thinking_budget': -1},
    ),
  };

  final List<ChatMessage> _chatHistory = [];
  String _modelName = _fallbackModelId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  void init(String modelName, [String languageCode = 'en']) {
    _modelName = _resolveModelName(modelName);
  }

  void updateModel(String modelName) {
    _modelName = _resolveModelName(modelName);
    notifyListeners();
  }

  void updateLanguage(String languageCode) {
    // Interface language is handled by SettingsService/UI.
    // Model response language follows the user's latest message.
  }

  Future<String?> sendMessage(String message) async {
    final trimmed = TextCleaner.clean(message);
    if (trimmed.isEmpty) return null;

    _isLoading = true;
    notifyListeners();

    try {
      _chatHistory.add(ChatMessage(role: 'user', content: trimmed));
      final recentHistory = _chatHistory.length > _maxContextMessages
          ? _chatHistory.sublist(_chatHistory.length - _maxContextMessages)
          : _chatHistory;
      final responseText = await _requestCompletion(
        modelName: _modelName,
        history: recentHistory,
      );
      final finalText = TextCleaner.clean(responseText);
      final safeText = finalText.isEmpty ? 'No response' : finalText;
      _chatHistory.add(ChatMessage(role: 'model', content: safeText));
      return safeText;
    } catch (e) {
      return 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> askSingleMessage(String prompt, {String? modelName}) async {
    final cleanedPrompt = TextCleaner.clean(prompt);
    if (cleanedPrompt.isEmpty) return '';
    return _requestCompletion(
      modelName: _resolveModelName(modelName ?? _modelName),
      history: [ChatMessage(role: 'user', content: cleanedPrompt)],
    );
  }

  Future<String> _requestCompletion({
    required String modelName,
    required List<ChatMessage> history,
  }) async {
    final model = _modelConfigs[modelName] ?? _modelConfigs[_fallbackModelId]!;
    // ignore: undefined_identifier
    final uri = Uri.parse('$apiBaseUrl/chat/completions');
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': autoLanguageInstruction},
      ..._buildApiMessages(history),
    ];
    final payload = <String, Object?>{
      'model': model.id,
      'messages': messages,
      'temperature': model.temperature,
      'top_p': model.topP,
      'max_tokens': model.maxTokens,
      'stream': false,
      ...model.extraBody,
    };
    if (model.frequencyPenalty != null) {
      payload['frequency_penalty'] = model.frequencyPenalty;
    }
    if (model.presencePenalty != null) {
      payload['presence_penalty'] = model.presencePenalty;
    }

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractApiError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid API response format');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw Exception('No choices returned by the model');
    }

    final choice = choices.first as Map;
    final message = choice['message'];
    if (message is! Map) {
      throw Exception('Missing message in model response');
    }

    final content = TextCleaner.clean(message['content']?.toString() ?? '');
    final reasoning = TextCleaner.clean(
      message['reasoning_content']?.toString() ?? '',
    );
    final finalText = content.isNotEmpty ? content : reasoning;

    if (finalText.isEmpty) {
      throw Exception('Empty model response');
    }
    return finalText;
  }

  List<Map<String, String>> _buildApiMessages(List<ChatMessage> history) {
    final messages = <Map<String, String>>[];

    for (final item in history) {
      final role = item.role == 'model' ? 'assistant' : 'user';
      final text = TextCleaner.clean(item.content);
      if (text.isEmpty) continue;

      if (messages.isNotEmpty && messages.last['role'] == role) {
        messages[messages.length - 1] = {
          'role': role,
          'content': '${messages.last['content']}\n$text',
        };
        continue;
      }

      messages.add({'role': role, 'content': text});
    }
    return messages;
  }

  String _extractApiError(String responseBody, int statusCode) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return 'API $statusCode: ${error['message']}';
        }
      }
      return 'API $statusCode: $responseBody';
    } catch (_) {
      return 'API $statusCode: $responseBody';
    }
  }

  String _resolveModelName(String modelName) {
    return _modelConfigs.containsKey(modelName) ? modelName : _fallbackModelId;
  }

  void loadHistoryFromSession(List<Map<String, String>> messages) {
    _chatHistory.clear();
    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final text = TextCleaner.clean(message['content'] ?? '');
      if (text.isEmpty) continue;
      _chatHistory.add(ChatMessage(role: role, content: text));
    }
    notifyListeners();
  }

  void clearHistory() {
    _chatHistory.clear();
    notifyListeners();
  }

  void startNewChat() {
    _chatHistory.clear();
    notifyListeners();
  }
}
