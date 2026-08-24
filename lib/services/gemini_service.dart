import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'text_cleaner.dart';
import 'watch_assistant_service.dart';

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}

class GeminiService with ChangeNotifier {
  // Google Gemini Key & Base URL
  static String get geminiApiKey {
    const fromEnv = String.fromEnvironment('GEMINI_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return utf8.decode(
      base64Decode('QVEuQWI4Uk42S2E4Sk85bGlNclVxdG5sVGhqODgzdWhnZl9OMUxVQi1fV2x2SlY3ZHNET2c='),
    );
  }
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // OpenRouter Key & Base URL
  static String get openRouterApiKey {
    const fromEnv = String.fromEnvironment('OPENROUTER_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return utf8.decode(
      base64Decode('c2stb3ItdjEtZWY4MGYxODIyY2Y0MWMxNDJmMjFkNTgzMDFjMmY5YzliZjlmMWQwYjY0NjEyN2RiOTU5YWRiMTBiNzA5NTEwNQ=='),
    );
  }
  static const String openRouterBaseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  static const int _maxContextMessages = 20;
  static const String autoLanguageInstruction =
      'Always respond concisely in the same language as the latest user message. '
      'Keep responses short, smartwatch-friendly, and formatted nicely without unnecessary fluff.';

  static const String modelUltra = 'gemini-3.7-flash';
  static const String modelPro = 'cohere/north-mini-code:free';
  static const String modelFast = 'liquid/lfm-2.5-2.6b:free';

  final List<ChatMessage> _chatHistory = [];
  final WatchAssistantService _watchAssistantService = WatchAssistantService();

  String _modelName = modelUltra;
  String _thinkingLevel = 'medium'; // 'off', 'low', 'medium', 'high'
  int _activeThinkingJobs = 0;
  DateTime? _thinkingStartedAt;
  Timer? _thinkingTicker;
  int _thinkingSeconds = 0;

  bool _isLoading = false;
  http.Client? _activeHttpClient;

  bool get isLoading => _isLoading;
  int get thinkingSeconds => _thinkingSeconds;
  String get thinkingLevel => _thinkingLevel;
  String get currentModel => _modelName;

  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  void init(String modelName, [String languageCode = 'en', String thinkingLevel = 'medium']) {
    _modelName = _resolveModelName(modelName);
    _thinkingLevel = thinkingLevel;
  }

  void updateModel(String modelName) {
    _modelName = _resolveModelName(modelName);
    notifyListeners();
  }

  void updateThinkingLevel(String level) {
    _thinkingLevel = level;
    notifyListeners();
  }

  void updateLanguage(String languageCode) {
    // Follows user language dynamically
  }

  void stopGeneration() {
    if (_activeHttpClient != null) {
      try {
        _activeHttpClient?.close();
      } catch (_) {}
      _activeHttpClient = null;
    }
    _stopThinking(forced: true);
  }

  Future<String?> sendMessage(String message) async {
    final trimmed = TextCleaner.clean(message);
    if (trimmed.isEmpty) return null;

    _startThinking();

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
      if (e.toString().contains('Connection closed') ||
          (e.toString().contains('ClientException') && !_isLoading)) {
        return 'Generation stopped';
      }
      return 'Error: $e';
    } finally {
      _stopThinking();
    }
  }

  Future<String> askSingleMessage(String prompt, {String? modelName}) async {
    final cleanedPrompt = TextCleaner.clean(prompt);
    if (cleanedPrompt.isEmpty) return '';
    _startThinking();
    try {
      return await _requestCompletion(
        modelName: _resolveModelName(modelName ?? _modelName),
        history: [ChatMessage(role: 'user', content: cleanedPrompt)],
      );
    } catch (e) {
      return 'Error: $e';
    } finally {
      _stopThinking();
    }
  }

  Future<String> _requestCompletion({
    required String modelName,
    required List<ChatMessage> history,
  }) async {
    _activeHttpClient?.close();
    final client = http.Client();
    _activeHttpClient = client;

    try {
      if (modelName == modelUltra) {
        return await _callGeminiApi(client, history);
      } else {
        return await _callOpenRouterApi(client, modelName, history);
      }
    } finally {
      if (_activeHttpClient == client) {
        _activeHttpClient = null;
      }
      client.close();
    }
  }

  Future<String> _callGeminiApi(
    http.Client client,
    List<ChatMessage> history,
  ) async {
    final uri = Uri.parse('$geminiBaseUrl/$modelUltra:generateContent?key=$geminiApiKey');

    final contents = <Map<String, dynamic>>[];

    // Add conversation history
    for (final item in history) {
      final role = item.role == 'model' ? 'model' : 'user';
      final text = TextCleaner.clean(item.content);
      if (text.isEmpty) continue;
      contents.add({
        'role': role,
        'parts': [
          {'text': text}
        ],
      });
    }

    int thinkingBudget = 0;
    switch (_thinkingLevel) {
      case 'low':
        thinkingBudget = 512;
        break;
      case 'medium':
        thinkingBudget = 2048;
        break;
      case 'high':
        thinkingBudget = 4096;
        break;
      case 'off':
      default:
        thinkingBudget = 0;
        break;
    }

    final generationConfig = <String, dynamic>{
      'temperature': 0.7,
      'maxOutputTokens': 1500,
    };

    if (thinkingBudget > 0) {
      generationConfig['thinkingConfig'] = {
        'thinkingBudget': thinkingBudget,
      };
    }

    final payload = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': autoLanguageInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': generationConfig,
    };

    final response = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractApiError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }

    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No output generated');
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;

    if (parts != null && parts.isNotEmpty) {
      final textBuffer = StringBuffer();
      for (final part in parts) {
        if (part is Map && part.containsKey('text')) {
          textBuffer.write(part['text']);
        }
      }
      final result = TextCleaner.clean(textBuffer.toString());
      if (result.isNotEmpty) return result;
    }

    throw Exception('Empty model response');
  }

  Future<String> _callOpenRouterApi(
    http.Client client,
    String modelName,
    List<ChatMessage> history,
  ) async {
    final uri = Uri.parse(openRouterBaseUrl);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': autoLanguageInstruction},
      ..._buildApiMessages(history),
    ];

    final payload = <String, dynamic>{
      'model': modelName,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1000,
      'stream': false,
    };

    final response = await client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $openRouterApiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://aiwatch.wearable.app',
        'X-Title': 'OleksandrAI Watch',
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
    if (modelName == modelUltra ||
        modelName == modelPro ||
        modelName == modelFast) {
      return modelName;
    }
    return modelUltra;
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

  void _startThinking() {
    _activeThinkingJobs += 1;
    if (_activeThinkingJobs > 1) return;

    _isLoading = true;
    _thinkingStartedAt = DateTime.now();
    _thinkingSeconds = 0;
    notifyListeners();

    _thinkingTicker?.cancel();
    _thinkingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _thinkingStartedAt;
      if (startedAt == null) return;
      final seconds = DateTime.now().difference(startedAt).inSeconds;
      if (seconds != _thinkingSeconds) {
        _thinkingSeconds = seconds;
        notifyListeners();
      }
    });

    _watchAssistantService.startThinkingStatus(label: 'Thinking...');
  }

  void _stopThinking({bool forced = false}) {
    if (forced) {
      _activeThinkingJobs = 0;
    } else if (_activeThinkingJobs > 0) {
      _activeThinkingJobs -= 1;
    }
    if (_activeThinkingJobs > 0) return;

    _thinkingTicker?.cancel();
    _thinkingTicker = null;
    _thinkingStartedAt = null;
    _thinkingSeconds = 0;
    _isLoading = false;
    notifyListeners();

    _watchAssistantService.stopThinkingStatus();
  }

  @override
  void dispose() {
    _thinkingTicker?.cancel();
    _activeHttpClient?.close();
    _watchAssistantService.stopThinkingStatus();
    super.dispose();
  }
}
