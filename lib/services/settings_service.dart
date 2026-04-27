import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService with ChangeNotifier {
  static const String defaultModel = 'gemini-2.5-flash';

  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.dark;
  String _language = 'en';
  String _model = defaultModel;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  String get model => _model;

  // Available models
  static const List<Map<String, String>> availableModels = [
    {'id': 'gemini-3.1-flash-lite-preview', 'name': 'fast 3.0'},
    {'id': defaultModel, 'name': '2.5 fast'},
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
}
