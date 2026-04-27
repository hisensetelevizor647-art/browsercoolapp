import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'text_cleaner.dart';

class GeminiService with ChangeNotifier {
  static const String apiKey = 'AIzaSyBDrlLzuoGuZIhaU7v5y_KQ2sLHdP83Lm0';
  static const int _maxContextMessages = 24;

  GenerativeModel? _model;
  String _languageCode = 'en';
  final List<Content> _chatHistory = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Content> get chatHistory => _chatHistory;

  static String _normalizeLanguage(String languageCode) {
    switch (languageCode) {
      case 'uk':
      case 'sk':
      case 'en':
        return languageCode;
      default:
        return 'en';
    }
  }

  static String buildLanguageInstruction(String languageCode) {
    switch (_normalizeLanguage(languageCode)) {
      case 'uk':
        return 'Відповідай лише українською мовою. '
            'Не використовуй китайські, японські або корейські символи. '
            'Відповідь має бути короткою і зрозумілою.';
      case 'sk':
        return 'Odpovedaj iba po slovensky. '
            'Nepouzivaj cinske, japonske ani korejske znaky. '
            'Odpoved musi byt strucna a jasna.';
      case 'en':
      default:
        return 'Reply in English only. '
            'Do not use Chinese, Japanese, or Korean characters. '
            'Keep responses concise.';
    }
  }

  void init(String modelName, [String languageCode = 'en']) {
    _model = GenerativeModel(model: modelName, apiKey: apiKey);
    _languageCode = _normalizeLanguage(languageCode);
  }

  void updateModel(String modelName) {
    _model = GenerativeModel(model: modelName, apiKey: apiKey);
    notifyListeners();
  }

  void updateLanguage(String languageCode) {
    _languageCode = _normalizeLanguage(languageCode);
  }

  Future<String?> sendMessage(String message) async {
    if (_model == null) return "Error: Model not initialized";
    final trimmed = TextCleaner.clean(
      message,
      disallowCjk: _languageCode != 'zh',
    );
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
        Content.text(buildLanguageInstruction(_languageCode)),
        ...recentHistory,
      ];
      final response = await _model!.generateContent(requestHistory);
      final responseText = TextCleaner.clean(
        response.text ?? '',
        disallowCjk: _languageCode != 'zh',
      );
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
      final text = (message['content'] ?? '').trim();
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

  // Start a new chat without clearing the displayed history
  void startNewChat() {
    _chatHistory.clear();
    notifyListeners();
  }
}
