import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'text_cleaner.dart';

class GeminiService with ChangeNotifier {
  static const String apiKey = 'AIzaSyBDrlLzuoGuZIhaU7v5y_KQ2sLHdP83Lm0';
  static const int _maxContextMessages = 24;
  static const String autoLanguageInstruction =
      'Always respond in the same language as the latest user message. '
      'If the user mixes languages, prefer the dominant language of the latest message. '
      'Keep responses concise unless the user asks for detail.';

  GenerativeModel? _model;
  final List<Content> _chatHistory = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Content> get chatHistory => _chatHistory;

  void init(String modelName, [String languageCode = 'en']) {
    _model = GenerativeModel(model: modelName, apiKey: apiKey);
  }

  void updateModel(String modelName) {
    _model = GenerativeModel(model: modelName, apiKey: apiKey);
    notifyListeners();
  }

  void updateLanguage(String languageCode) {
    // Interface language is handled by SettingsService/UI.
    // Model response language follows the user's latest message.
  }

  Future<String?> sendMessage(String message) async {
    if (_model == null) return "Error: Model not initialized";
    final trimmed = TextCleaner.clean(message);
    if (trimmed.isEmpty) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final content = Content.text(trimmed);
      _chatHistory.add(content);

      final startIndex = _chatHistory.length > _maxContextMessages
          ? _chatHistory.length - _maxContextMessages
          : 0;
      final recentHistory = _chatHistory.sublist(startIndex);
      final requestHistory = <Content>[
        Content.text(autoLanguageInstruction),
        ...recentHistory,
      ];

      final response = await _model!.generateContent(requestHistory);
      final responseText = TextCleaner.clean(response.text ?? '');
      final finalText = responseText.isEmpty ? 'No response' : responseText;
      _chatHistory.add(Content.model([TextPart(finalText)]));

      return finalText;
    } catch (e) {
      return "Error: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void loadHistoryFromSession(List<Map<String, String>> messages) {
    _chatHistory.clear();
    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final text = TextCleaner.clean(message['content'] ?? '');
      if (text.isEmpty) continue;

      if (role == 'model') {
        _chatHistory.add(Content.model([TextPart(text)]));
      } else {
        _chatHistory.add(Content.text(text));
      }
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
