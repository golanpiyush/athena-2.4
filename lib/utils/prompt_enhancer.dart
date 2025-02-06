import 'package:athena/models/analysis_result.dart';
import 'package:athena/models/message.dart';
import 'package:athena/models/session.dart';
import 'package:athena/utils/conversation_analyzer.dart';

class PromptEnhancer {
  final ConversationAnalyzer _analyzer;

  PromptEnhancer(this._analyzer);

  String enhancePrompt(String basePrompt, String userMessage, Session session) {
    final analysis = _analyzer.analyzeMessage(userMessage, session);

    return '''
${_buildContextualAwareness(analysis, session)}

$basePrompt

${_buildResponseGuidelines(analysis)}

User message: $userMessage
''';
  }

  String _buildContextualAwareness(AnalysisResult analysis, Session session) {
    final context = analysis.context;
    final recentMessages = session.messages.reversed.take(3);

    return '''
<context>
${context.requiresContext ? "Consider previous context:" : ""}
${recentMessages.isEmpty ? "" : "Recent messages: ${_formatRecentMessages(recentMessages)}"}
${context.topicShift ? "Note: User is changing topics" : ""}
Topic: ${analysis.topic.mainTopic} (confidence: ${(analysis.topic.confidence * 100).toStringAsFixed(0)}%)
</context>
''';
  }

  String _formatRecentMessages(Iterable<Message> messages) {
    return messages.map((m) => "${m.role}: ${m.content}").join("\n");
  }

  String _buildResponseGuidelines(AnalysisResult analysis) {
    return '''
<guidelines>
- Emotion: ${_getEmotionalGuideline(analysis.emotion)}
- Intent: ${_getIntentGuideline(analysis.intent)}
- Complexity: ${_getComplexityGuideline(analysis.complexity)}
</guidelines>
''';
  }

  String _getEmotionalGuideline(String emotion) {
    switch (emotion) {
      case 'joy':
        return 'Match positive energy while staying professional';
      case 'frustration':
        return 'Be solution-focused and reassuring';
      case 'confusion':
        return 'Provide clear, step-by-step explanations';
      case 'curiosity':
        return 'Provide detailed insights and encourage exploration';
      default:
        return 'Maintain professional and helpful tone';
    }
  }

  String _getIntentGuideline(String intent) {
    switch (intent) {
      case 'question':
        return 'Provide clear, direct answers';
      case 'request':
        return 'Focus on actionable solutions';
      case 'correction':
        return 'Acknowledge and clarify differences';
      default:
        return 'Engage constructively with user\'s input';
    }
  }

  String _getComplexityGuideline(ComplexityAnalysis complexity) {
    if (complexity.technicalTermCount > 2) {
      return 'Maintain technical precision while ensuring clarity';
    } else if (complexity.averageWordLength > 6) {
      return 'Match language complexity while staying accessible';
    }
    return 'Adapt to user\'s communication style';
  }
}
