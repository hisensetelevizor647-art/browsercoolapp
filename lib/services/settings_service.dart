import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService with ChangeNotifier {
  static const String modelUltra = 'gemini-3.7-flash';
  static const String modelPro = 'cohere/north-mini-code:free';
  static const String modelFast = 'liquid/lfm-2.5-2.6b:free';

  static const String defaultModel = modelUltra;

  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.dark;
  String _language = 'en';
  String _model = defaultModel;
  String _thinkingLevel = 'medium'; // 'off', 'low', 'medium', 'high'
  String _backgroundTheme = 'default';

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  String get model => _model;
  String get thinkingLevel => _thinkingLevel;
  String get backgroundTheme => _backgroundTheme;

  // Available models: 4.0 Ultra, 4.0 Pro, 4.0 Fast
  static const List<Map<String, String>> availableModels = [
    {'id': modelUltra, 'name': '4.0 ultra'},
    {'id': modelPro, 'name': '4.0 pro'},
    {'id': modelFast, 'name': '4.0 fast'},
  ];

  // Display name mapping logic
  String get modelDisplayName {
    for (var m in availableModels) {
      if (m['id'] == _model) {
        return m['name']!;
      }
    }
    return availableModels.first['name']!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs == null) return;

    final themeIndex =
        _prefs!.getInt('themeMode') ?? 2; // Default to dark (index 2)
    _themeMode = ThemeMode.values[themeIndex];

    _language = _prefs!.getString('language') ?? 'en';
    final storedModel = _prefs!.getString('model');
    final isKnownModel = availableModels.any((m) => m['id'] == storedModel);
    _model = isKnownModel ? storedModel! : defaultModel;
    if (!isKnownModel) {
      _prefs!.setString('model', _model);
    }
    _thinkingLevel = _prefs!.getString('thinkingLevel') ?? 'medium';
    _backgroundTheme = _prefs!.getString('backgroundTheme') ?? 'default';

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs?.setInt('themeMode', mode.index);
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    await _prefs?.setString('language', lang);
  }

  Future<void> setModel(String newModel) async {
    if (!availableModels.any((m) => m['id'] == newModel)) return;
    _model = newModel;
    notifyListeners();
    await _prefs?.setString('model', newModel);
  }

  Future<void> setThinkingLevel(String level) async {
    _thinkingLevel = level;
    notifyListeners();
    await _prefs?.setString('thinkingLevel', level);
  }

  Future<void> setBackgroundTheme(String theme) async {
    _backgroundTheme = theme;
    notifyListeners();
    await _prefs?.setString('backgroundTheme', theme);
  }
}
