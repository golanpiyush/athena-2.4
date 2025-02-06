import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class Message {
  final String role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Message({
    required this.role,
    required this.content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? {};

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        role: json['role'],
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
        metadata: json['metadata'] ?? {},
      );
}
