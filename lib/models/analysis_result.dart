class AnalysisResult {
  final TopicAnalysis topic;
  final String emotion;
  final String intent;
  final ContextAnalysis context;
  final ComplexityAnalysis complexity;

  AnalysisResult({
    required this.topic,
    required this.emotion,
    required this.intent,
    required this.context,
    required this.complexity,
  });
}

class TopicAnalysis {
  final String mainTopic;
  final double confidence;
  final List<String> relatedTopics;

  TopicAnalysis({
    required this.mainTopic,
    required this.confidence,
    required this.relatedTopics,
  });
}

class ContextAnalysis {
  final bool requiresContext;
  final bool referencesHistory;
  final bool continuesThread;
  final bool topicShift;

  ContextAnalysis({
    required this.requiresContext,
    required this.referencesHistory,
    required this.continuesThread,
    required this.topicShift,
  });
}

class ComplexityAnalysis {
  final int length;
  final int wordCount;
  final double averageWordLength;
  final int technicalTermCount;

  ComplexityAnalysis({
    required this.length,
    required this.wordCount,
    required this.averageWordLength,
    required this.technicalTermCount,
  });
}
