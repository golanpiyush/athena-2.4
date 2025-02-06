import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import 'package:collection/collection.dart';

class SessionManager {
  static const String _storageKey = 'enhanced_sessions_v1';
  Map<String, Session> _sessions = {};
  String? _currentSessionId;

  static Future<SessionManager> initialize() async {
    final manager = SessionManager();
    await manager.loadSessions();
    return manager;
  }

  Future<void> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? sessionsData = prefs.getString(_storageKey);

      if (sessionsData != null) {
        final Map<String, dynamic> decoded = json.decode(sessionsData);
        _sessions = decoded.map(
          (key, value) => MapEntry(key, Session.fromJson(value)),
        );
      }
    } catch (e) {
      print("Error loading sessions: $e");
    }
  }

  Future<void> saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = json.encode(
        _sessions.map((key, session) => MapEntry(key, session.toJson())),
      );
      await prefs.setString(_storageKey, sessionsJson);
    } catch (e) {
      print("Error saving sessions: $e");
    }
  }

  Session createNewSession(String title) {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final session = Session(
      id: sessionId,
      title: title,
    );
    _sessions[sessionId] = session;
    _currentSessionId = sessionId;
    saveSessions();
    return session;
  }

  Session? getCurrentSession() {
    return _currentSessionId != null ? _sessions[_currentSessionId] : null;
  }

  void setCurrentSession(String sessionId) {
    if (_sessions.containsKey(sessionId)) {
      _currentSessionId = sessionId;
    }
  }

  String constructPrompt(String userMessage, String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return userMessage;

    final contextPrompt = session.getContextualPrompt();
    return '''
$contextPrompt

Current user message: $userMessage

Please provide a response that takes into account the conversation context and history provided above.
''';
  }

  Future<void> addMessageToSession(
    String sessionId,
    String role,
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final session = _sessions[sessionId];
    if (session != null) {
      session.addMessage(role, content, metadata: metadata);
      await saveSessions();
    }
  }

  List<Session> getRecentSessions({int limit = 10}) {
    return _sessions.values
        .where((session) => session.isActive)
        .sorted((a, b) => b.lastUpdated.compareTo(a.lastUpdated)) // Works now
        .take(limit)
        .toList();
  }

  Future<void> deleteSession(String sessionId) async {
    if (_sessions.containsKey(sessionId)) {
      _sessions[sessionId]!.isActive = false;
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
      }
      await saveSessions();
    }
  }

  String? findSessionByTopic(String topic) {
    return _sessions.values
        .where((session) =>
            session.context.topics.contains(topic.toLowerCase()) ||
            session.context.currentTopic?.toLowerCase() == topic.toLowerCase())
        .map((session) => session.id)
        .firstOrNull;
  }
}
