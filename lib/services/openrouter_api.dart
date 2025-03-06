import 'dart:async';
import 'dart:convert';
import 'package:athena/utils/conversation_analyzer.dart';
import 'package:athena/utils/prompt_enhancer.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation_context.dart';
import '../models/session.dart';
import 'package:collection/collection.dart';

class APIResponse {
  final String? content;
  final String? error;
  final bool isSuccess;
  final int? statusCode;

  APIResponse({
    this.content,
    this.error,
    this.isSuccess = false,
    this.statusCode,
  });
}

class OpenRouterAPI {
  static const String _athenaApiKey = '';
  
  static const String _storageKey = 'enhanced_sessions_v1';

  static Map<String, Session> _sessions = {};
  static String? _currentSessionId;

  // Initialize the API with stored sessions
  static Future<void> initialize() async {
    await _loadSessions();
  }

  final _analyzer = ConversationAnalyzer();

  late final PromptEnhancer _promptEnhancer;

  // Load sessions from SharedPreferences
  static Future<void> _loadSessions() async {
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

  // Save sessions to SharedPreferences
  static Future<void> _saveSessions() async {
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

  Future<Session> startNewConversation(String userMessage) async {
    final session = await OpenRouterAPI._getOrCreateSession(userMessage,
        isNewConversation: true);
    print("Started new conversation with session: ${session.id}");
    return session; // ✅ Return session instead of void
  }

  static Future<Session> _getOrCreateSession(String userMessage,
      {bool isNewConversation = false}) async {
    // If it's a new conversation, create a fresh session
    if (isNewConversation) {
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      final generatedTitle = _generateSessionTitle(userMessage);

      final newSession = Session(
        id: sessionId,
        title: generatedTitle,
        context:
            ConversationContext(), // Start with a fresh context and no messages
      );

      // Save the new session in memory
      _sessions[sessionId] = newSession;
      _currentSessionId = sessionId;

      // Save all sessions to SharedPreferences
      await _saveSessions();

      return newSession;
    }

    // If no new conversation, check if the current session is valid
    if (_currentSessionId != null && _sessions.containsKey(_currentSessionId)) {
      final session = _sessions[_currentSessionId!]!;
      if (DateTime.now().difference(session.lastUpdated).inHours < 1) {
        // Return the current session if it's still valid
        return session;
      }
    }

    // If the current session is expired, create a new one
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final generatedTitle = _generateSessionTitle(userMessage);

    final newSession = Session(
      id: sessionId,
      title: generatedTitle,
      context: ConversationContext(), // Fresh context for the new session
    );

    _sessions[sessionId] = newSession;
    _currentSessionId = sessionId;

    // Save all sessions to SharedPreferences
    await _saveSessions();

    return newSession;
  }

  static String _generateSessionTitle(String userMessage) {
    List<String> words = userMessage.split(' ');
    if (words.length > 4) {
      return words.take(4).join(' ') + "..."; // Take first 4 words
    }
    return userMessage; // Use full message if it's short
  }
  
  // Utility methods for session management
  static List<Session> getRecentSessions({int limit = 10}) {
    return _sessions.values
        .where((session) => session.isActive)
        .toList()
        .sorted((a, b) => b.lastUpdated.compareTo(a.lastUpdated))
        .take(limit)
        .toList();
  }

  static Future<void> deleteSession(String sessionId) async {
    if (_sessions.containsKey(sessionId)) {
      _sessions[sessionId]!.isActive = false;
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
      }
      await _saveSessions();
    }
  }

  static String? findSessionByTopic(String topic) {
    return _sessions.values
        .where((session) =>
            session.context.topics.contains(topic.toLowerCase()) ||
            session.context.currentTopic?.toLowerCase() == topic.toLowerCase())
        .map((session) => session.id)
        .firstOrNull;
  }
}

class PromptManager {
  final ConversationAnalyzer _analyzer;
  final PromptEnhancer _promptEnhancer;

  PromptManager()
      : _analyzer = ConversationAnalyzer(),
        _promptEnhancer = PromptEnhancer(ConversationAnalyzer());

  String getEnhancedPrompt(String userMessage, Session session) {
    return _promptEnhancer.enhancePrompt(
        session.context.getContextualPrompt(), userMessage, session);
  }
}
