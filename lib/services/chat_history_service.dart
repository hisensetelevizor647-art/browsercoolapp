import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'text_cleaner.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<Map<String, String>> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'messages': messages,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    messages: (json['messages'] as List<dynamic>)
        .map((e) => Map<String, String>.from(e as Map))
        .toList(),
  );
}

class ChatHistoryService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<ChatSession> _sessions = [];
  String? _currentSessionId;

  List<ChatSession> get sessions => _sessions;
  String? get currentSessionId => _currentSessionId;

  ChatSession? get currentSession {
    if (_currentSessionId == null) return null;
    try {
      return _sessions.firstWhere((s) => s.id == _currentSessionId);
    } catch (e) {
      return null;
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSessions();
  }

  void _loadSessions() {
    if (_prefs == null) return;

    final sessionsJson = _prefs!.getString('chat_sessions');
    if (sessionsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(sessionsJson);
        _sessions = decoded.map((e) => ChatSession.fromJson(e)).toList();
        _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {
        _sessions = [];
      }
    }

    _currentSessionId = _prefs!.getString('current_session_id');
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    if (_prefs == null) return;
    final json = jsonEncode(_sessions.map((e) => e.toJson()).toList());
    await _prefs!.setString('chat_sessions', json);
    if (_currentSessionId != null) {
      await _prefs!.setString('current_session_id', _currentSessionId!);
    }
  }

  Future<String> createNewSession() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = ChatSession(
      id: id,
      title: 'New Chat',
      createdAt: DateTime.now(),
      messages: [],
    );
    _sessions.insert(0, session);
    _currentSessionId = id;
    await _saveSessions();
    notifyListeners();
    return id;
  }

  Future<void> setCurrentSession(String sessionId) async {
    _currentSessionId = sessionId;
    await _prefs?.setString('current_session_id', sessionId);
    notifyListeners();
  }

  Future<void> addMessageToCurrentSession(String role, String content) async {
    final cleanedContent = TextCleaner.clean(content, disallowCjk: true);
    if (cleanedContent.isEmpty) return;

    if (_currentSessionId == null) {
      await createNewSession();
    }

    final sessionIndex = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex].messages.add({
        'role': role,
        'content': cleanedContent,
      });

      // Update title if it's the first user message
      if (_sessions[sessionIndex].messages.length == 1 && role == 'user') {
        final title = cleanedContent.length > 30
            ? '${cleanedContent.substring(0, 30)}...'
            : cleanedContent;
        _sessions[sessionIndex] = ChatSession(
          id: _sessions[sessionIndex].id,
          title: title,
          createdAt: _sessions[sessionIndex].createdAt,
          messages: _sessions[sessionIndex].messages,
        );
      }

      await _saveSessions();
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_currentSessionId == sessionId) {
      _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
    }
    await _saveSessions();
    notifyListeners();
  }

  List<Map<String, String>> getCurrentSessionMessages() {
    return currentSession?.messages ?? [];
  }
}
