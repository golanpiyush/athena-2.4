// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationContext _$ConversationContextFromJson(Map<String, dynamic> json) =>
    ConversationContext(
      topics:
          (json['topics'] as List<dynamic>?)?.map((e) => e as String).toList(),
      currentTopic: json['currentTopic'] as String?,
      relatedTerms: (json['relatedTerms'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      lastUpdated:
          ConversationContext._dateTimeFromJson(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$ConversationContextToJson(
        ConversationContext instance) =>
    <String, dynamic>{
      'topics': instance.topics,
      'currentTopic': instance.currentTopic,
      'relatedTerms': instance.relatedTerms,
      'lastUpdated': ConversationContext._dateTimeToJson(instance.lastUpdated),
    };
