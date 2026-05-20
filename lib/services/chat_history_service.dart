import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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
  static const _chatSessionsKey = 'chat_sessions';
  static const _currentSessionIdKey = 'current_session_id';
  static const _voiceTranscriptKey = 'voice_transcript_text';

  SharedPreferences? _prefs;
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  String _voiceTranscriptText = '';

  List<ChatSession> get sessions => _sessions;
  String? get currentSessionId => _currentSessionId;
  String get voiceTranscriptText => _voiceTranscriptText;

  ChatSession? get currentSession {
    if (_currentSessionId == null) return null;
    try {
      return _sessions.firstWhere((s) => s.id == _currentSessionId);
    } catch (e) {
      return null;
    }
  }

  Future<File> get _sessionsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/chat_sessions.json');
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final file = await _sessionsFile;
      if (await file.exists()) {
        final sessionsJson = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(sessionsJson);
        _sessions = decoded.map((e) => ChatSession.fromJson(e)).toList();
        _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (_prefs != null) {
        // Fallback to migrate from SharedPreferences
        final sessionsJson = _prefs!.getString(_chatSessionsKey);
        if (sessionsJson != null) {
          final List<dynamic> decoded = jsonDecode(sessionsJson);
          _sessions = decoded.map((e) => ChatSession.fromJson(e)).toList();
          _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          await _saveSessions(); // Save to new file location
        }
      }
    } catch (_) {
      _sessions = [];
    }

    _currentSessionId = _prefs?.getString(_currentSessionIdKey);
    _voiceTranscriptText = _prefs?.getString(_voiceTranscriptKey) ?? '';
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    try {
      final file = await _sessionsFile;
      final jsonStr = jsonEncode(_sessions.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
      if (_currentSessionId != null && _prefs != null) {
        await _prefs!.setString(_currentSessionIdKey, _currentSessionId!);
      }
    } catch (e) {
      debugPrint('Error saving sessions: $e');
    }
  }

  Future<String> createNewSession({String title = 'New Chat'}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = ChatSession(
      id: id,
      title: TextCleaner.clean(title).isEmpty
          ? 'New Chat'
          : TextCleaner.clean(title),
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
    await _prefs?.setString(_currentSessionIdKey, sessionId);
    notifyListeners();
  }

  Future<void> addMessageToCurrentSession(String role, String content) async {
    final cleanedContent = TextCleaner.clean(content);
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

  Future<void> appendVoiceTranscript({
    required String role,
    required String content,
  }) async {
    final cleanedRole = TextCleaner.clean(role).toUpperCase();
    final cleanedContent = TextCleaner.clean(content);
    if (cleanedRole.isEmpty || cleanedContent.isEmpty) return;

    final timestamp = _formatTimestamp(DateTime.now());
    final line = '[$timestamp] $cleanedRole: $cleanedContent';
    _voiceTranscriptText = _voiceTranscriptText.isEmpty
        ? line
        : '$_voiceTranscriptText\n$line';

    await _prefs?.setString(_voiceTranscriptKey, _voiceTranscriptText);
    notifyListeners();
  }

  Future<void> clearVoiceTranscript() async {
    _voiceTranscriptText = '';
    await _prefs?.setString(_voiceTranscriptKey, _voiceTranscriptText);
    notifyListeners();
  }

  String _formatTimestamp(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}
