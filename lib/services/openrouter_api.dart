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
  static const String _geminiApiKey = 'AIzaSyDbpsAQPli7kodRhRXVQAtnzFK_ntCuml0';
  static const String _groqApiKey =
      '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';
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

  static Future<APIResponse> fetchGeminiAIResponse(
      String userMessage, Session session) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey');

    // Get the contextual prompt from the session's conversation context
    final contextualPrompt = session.context.getContextualPrompt();

    // Modify the prompt to only include essential context
    final fullPrompt = '''
$contextualPrompt
User message: $userMessage
''';
    final promptManager = PromptManager();
    final enhancedPrompt =
        promptManager.getEnhancedPrompt(userMessage, session);

    final requestBody = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": enhancedPrompt}
          ]
        }
      ]
    };

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final content =
            responseBody['candidates'][0]['content']['parts'][0]['text'];

        // Add messages to session
        session.addMessage('user', userMessage);
        session.addMessage('assistant', content);
        await _saveSessions();
        print(responseBody);
        return APIResponse(content: content, isSuccess: true);
      } else {
        return APIResponse(
            error: "Request failed with status: ${response.statusCode}");
      }
    } catch (e) {
      return APIResponse(error: "Error connecting to Gemini: $e");
    }
  }

  static Future<APIResponse> fetchGroqAIResponse(
      String userMessage, Session session) async {
    // Get the contextual prompt from the session's conversation context
    final contextualPrompt = session.context.getContextualPrompt();

    final fullPrompt = '''
$contextualPrompt

User message: $userMessage

Provide a response that maintains context of the conversation.
''';

    final requestBody = {
      "model": "llama-3.1-8b-instant",
      "messages": [
        {"role": "user", "content": fullPrompt}
      ],
      "temperature": 0.5,
      "max_completion_tokens": 1024,
      "top_p": 1,
      "stream": false,
    };

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final content = responseBody['choices'][0]['message']['content'];

        // Add messages to session
        session.addMessage('user', userMessage);
        session.addMessage('assistant', content);
        await _saveSessions();

        return APIResponse(content: content, isSuccess: true);
      } else {
        return APIResponse(
            error: "Request failed with status: ${response.statusCode}");
      }
    } catch (e) {
      return APIResponse(error: "Error connecting to Groq: $e");
    }
  }

  static Future<APIResponse> fetchAIResponse(String userMessage) async {
    if (userMessage.trim().isEmpty) {
      return APIResponse(error: "Message cannot be empty");
    }

    // Get or create session
    final session = await _getOrCreateSession(userMessage);

    try {
      final geminiResponse = await fetchGeminiAIResponse(userMessage, session)
          .timeout(const Duration(seconds: 7));

      if (geminiResponse.isSuccess) {
        return geminiResponse;
      } else {
        print("Gemini failed, falling back to Groq...");
        return await fetchGroqAIResponse(userMessage, session);
      }
    } catch (e) {
      print("Gemini timed out, falling back to Groq...");
      return await fetchGroqAIResponse(userMessage, session);
    }
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
