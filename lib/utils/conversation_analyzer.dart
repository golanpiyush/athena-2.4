import 'package:athena/models/analysis_result.dart';
import 'package:athena/models/message.dart';
import 'package:athena/models/session.dart';

class ConversationAnalyzer {
  static final ConversationAnalyzer _instance =
      ConversationAnalyzer._internal();
  factory ConversationAnalyzer() => _instance;
  ConversationAnalyzer._internal();

  // Expanded topic categories with additional technical and health-related terms,
  // including a new 'mental_health' category.
  final Map<String, Map<String, double>> _topicWeights = {
    'technology': {
      'coding': 1.5,
      'programming': 1.5,
      'software': 1.2,
      'development': 1.3,
      'api': 1.2,
      'database': 1.2,
      'frontend': 1.1,
      'backend': 1.1,
      'mobile': 1.1,
      'web': 1.1,
      'cloud': 1.2,
      'security': 1.3,
      'machine learning': 1.4,
      'ai': 1.4,
    },
    'business': {
      'market': 1.2,
      'strategy': 1.1,
      'company': 1.0,
      'startup': 1.2,
      'investment': 1.3,
      'revenue': 1.2,
      'customer': 1.1,
      'product': 1.0,
      'service': 1.0,
    },
    'health': {
      'fitness': 1.2,
      'diet': 1.1,
      'exercise': 1.2,
      'nutrition': 1.1,
      'wellness': 1.3,
      'mental health': 1.4,
    },
    'entertainment': {
      'music': 1.3,
      'movies': 1.2,
      'games': 1.1,
      'tv': 1.0,
      'concert': 1.3,
      'festival': 1.2,
    },
    'science': {
      'research': 1.2,
      'experiment': 1.2,
      'theory': 1.1,
      'physics': 1.3,
      'chemistry': 1.3,
      'biology': 1.2,
    },
    // New mental_health category for detecting mental health conditions
    'mental_health': {
      'panic attack': 1.5,
      'panic attacks': 1.5,
      'panic': 1.4,
      'anxiety': 1.4,
      'anxious': 1.4,
      'adhd': 1.3,
      'attention deficit': 1.3,
      'overwhelmed': 1.2,
      'stress': 1.2,
      // Optionally, add more terms such as 'depression' if needed:
      // 'depression': 1.5,
    },
    // Add more categories as needed.
  };

  // Enhanced contextual patterns with additional patterns for both emotion and intent.
  // The emotion map now includes an "anxiety" key to catch messages with anxious sentiments.
  final Map<String, Map<String, List<String>>> _contextualPatterns = {
    'emotion': {
      'joy': ['happy', 'great', 'excellent', '😊', '👍'],
      'frustration': ['annoyed', 'issue', 'problem', '😤'],
      'confusion': ['confused', 'unclear', 'don\'t understand', '🤔'],
      'curiosity': ['interested', 'tell me more', 'how does', '🤓'],
      'sadness': ['sad', 'down', 'unhappy', '😭', '😢'],
      'anger': ['mad', 'furious', 'irate', '😠', '😡'],
      // New emotion patterns for anxiety-related language.
      'anxiety': [
        'anxious',
        'anxiety',
        'panic',
        'panic attack',
        'nervous',
        'stressed',
        'overwhelmed'
      ],
    },
    'intent': {
      'question': ['how', 'what', 'why', 'when', 'where', '?'],
      'request': ['can you', 'please', 'could you', 'help'],
      'statement': ['i think', 'i believe', 'in my opinion'],
      'correction': ['actually', 'however', 'but', 'instead'],
      'clarification': [
        'could you explain',
        'what do you mean',
        'i am confused about'
      ],
    }
  };

  AnalysisResult analyzeMessage(String message, Session session) {
    final lowercaseMessage = message.toLowerCase();

    return AnalysisResult(
      topic: _detectTopic(lowercaseMessage, session),
      emotion: _detectEmotion(lowercaseMessage),
      intent: _detectIntent(lowercaseMessage),
      context: _analyzeContext(lowercaseMessage, session),
      complexity: _assessComplexity(message),
    );
  }

  TopicAnalysis _detectTopic(String message, Session session) {
    Map<String, double> scores = {};

    // Apply a base score if there's a current topic in the session.
    if (session.context.currentTopic != null) {
      scores[session.context.currentTopic!] = 0.5;
    }

    // Tally scores for each topic category.
    for (var category in _topicWeights.entries) {
      double score = 0;
      for (var term in category.value.entries) {
        if (message.contains(term.key)) {
          score += term.value;
        }
      }
      if (score > 0) {
        scores[category.key] = (scores[category.key] ?? 0) + score;
      }
    }

    // Sort topics by score and return the main and related topics.
    final sortedTopics = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return TopicAnalysis(
      mainTopic: sortedTopics.isEmpty ? 'general' : sortedTopics.first.key,
      confidence: sortedTopics.isEmpty ? 0.0 : sortedTopics.first.value / 5.0,
      relatedTopics: sortedTopics.skip(1).take(2).map((e) => e.key).toList(),
    );
  }

  String _detectEmotion(String message) {
    final emotions = _contextualPatterns['emotion']!;
    Map<String, int> matches = {};

    for (var emotion in emotions.entries) {
      int count =
          emotion.value.where((pattern) => message.contains(pattern)).length;
      if (count > 0) matches[emotion.key] = count;
    }

    return matches.isEmpty
        ? 'neutral'
        : matches.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _detectIntent(String message) {
    final intents = _contextualPatterns['intent']!;
    Map<String, int> matches = {};

    for (var intent in intents.entries) {
      int count =
          intent.value.where((pattern) => message.contains(pattern)).length;
      if (count > 0) matches[intent.key] = count;
    }

    return matches.isEmpty
        ? 'statement'
        : matches.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  ContextAnalysis _analyzeContext(String message, Session session) {
    final recentMessages = session.messages.reversed.take(5).toList();

    return ContextAnalysis(
      requiresContext: _needsContext(message),
      referencesHistory: _referencesHistory(message, recentMessages),
      continuesThread: _continuesThread(message, recentMessages),
      topicShift: _detectTopicShift(message, session.context.currentTopic),
    );
  }

  bool _needsContext(String message) {
    final contextualWords = ['it', 'that', 'this', 'they', 'these', 'those'];
    return contextualWords.any((word) => message.split(' ').contains(word));
  }

  bool _referencesHistory(String message, List<Message> history) {
    if (history.isEmpty) return false;

    final keywords = history
        .map((m) => m.content.toLowerCase().split(' '))
        .expand((words) => words)
        .where((word) => word.length > 4)
        .toSet();

    return keywords.any((word) => message.contains(word));
  }

  bool _continuesThread(String message, List<Message> history) {
    if (history.isEmpty) return false;

    final continuationMarkers = [
      'and',
      'also',
      'additionally',
      'furthermore',
      'moreover',
      'related to that',
      'speaking of',
      'on that note'
    ];

    return continuationMarkers.any(
      (marker) => message.toLowerCase().startsWith(marker),
    );
  }

  bool _detectTopicShift(String message, String? currentTopic) {
    if (currentTopic == null) return false;

    final newTopicMarkers = [
      'changing the subject',
      'on another note',
      'by the way',
      'switching gears',
      'moving on to'
    ];

    return newTopicMarkers.any(
      (marker) => message.toLowerCase().contains(marker),
    );
  }

  ComplexityAnalysis _assessComplexity(String message) {
    return ComplexityAnalysis(
      length: message.length,
      wordCount: message.split(' ').length,
      averageWordLength: _calculateAverageWordLength(message),
      technicalTermCount: _countTechnicalTerms(message),
    );
  }

  double _calculateAverageWordLength(String message) {
    final words = message.split(' ');
    if (words.isEmpty) return 0;
    return words.map((w) => w.length).reduce((a, b) => a + b) / words.length;
  }

  int _countTechnicalTerms(String message) {
    final technicalTerms = _topicWeights['technology']?.keys ?? {};
    return message
        .toLowerCase()
        .split(' ')
        .where((word) => technicalTerms.contains(word))
        .length;
  }
}
