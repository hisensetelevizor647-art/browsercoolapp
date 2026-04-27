import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> init() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> setLanguageCode(String languageCode) async {
    String locale;
    switch (languageCode) {
      case 'uk':
        locale = 'uk-UA';
        break;
      case 'sk':
        locale = 'sk-SK';
        break;
      case 'en':
      default:
        locale = 'en-US';
        break;
    }
    await _flutterTts.setLanguage(locale);
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
