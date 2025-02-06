import 'package:json_annotation/json_annotation.dart';
import 'conversation_context.dart';
import 'message.dart';

@JsonSerializable()
class Session {
  final String id;
  final List<Message> messages;
  final DateTime createdAt;
  DateTime lastUpdated;
  final ConversationContext context;
  final String title;
  bool isActive;

  Session({
    required this.id,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastUpdated,
    ConversationContext? context,
    String? title,
    this.isActive = true,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now(),
        context = context ?? ConversationContext(),
        title = title ?? 'New Conversation';

  Map<String, dynamic> toJson() => {
        'id': id,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastUpdated': lastUpdated.toIso8601String(),
        'context': context.toJson(),
        'title': title,
        'isActive': isActive,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'],
        messages:
            (json['messages'] as List).map((m) => Message.fromJson(m)).toList(),
        createdAt: DateTime.parse(json['createdAt']),
        lastUpdated: DateTime.parse(json['lastUpdated']),
        context: ConversationContext.fromJson(json['context']),
        title: json['title'],
        isActive: json['isActive'] ?? true,
      );

  void addMessage(String role, String content,
      {Map<String, dynamic>? metadata}) {
    messages.add(Message(
      role: role,
      content: content,
      metadata: metadata,
    ));
    lastUpdated = DateTime.now();
    context.updateContext(content);
  }

  String getContextualPrompt() {
    if (messages.isEmpty) return '';

    final contextBuilder = StringBuffer();

    if (context.currentTopic != null) {
      contextBuilder
          .writeln("Current topic of discussion: ${context.currentTopic}");

      final relatedTerms = context.relatedTerms[context.currentTopic];
      if (relatedTerms != null && relatedTerms.isNotEmpty) {
        contextBuilder.writeln("Related concepts: ${relatedTerms.join(', ')}");
      }
    }

    if (messages.isNotEmpty) {
      contextBuilder.writeln("\nRecent conversation summary:");
      for (var i = messages.length - 1;
          i >= 0 && i >= messages.length - 3;
          i--) {
        final msg = messages[i];
        contextBuilder.writeln("${msg.role}: ${msg.content}");
      }
    }

    return contextBuilder.toString();
  }
}
