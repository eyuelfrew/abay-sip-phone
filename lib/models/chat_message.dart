import 'dart:convert';

enum MessageDirection { inbound, outbound }

class ChatMessage {
  final String id;
  final String peerUri;
  final String body;
  final DateTime at;
  final MessageDirection direction;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.peerUri,
    required this.body,
    required this.at,
    required this.direction,
    this.read = true,
  });

  ChatMessage copyWith({bool? read}) => ChatMessage(
        id: id,
        peerUri: peerUri,
        body: body,
        at: at,
        direction: direction,
        read: read ?? this.read,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'peerUri': peerUri,
        'body': body,
        'at': at.toIso8601String(),
        'direction': direction.name,
        'read': read,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        peerUri: (map['peerUri'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        at: DateTime.tryParse((map['at'] as String?) ?? '') ?? DateTime.now(),
        direction: MessageDirection.values.firstWhere(
          (e) => e.name == map['direction'],
          orElse: () => MessageDirection.outbound,
        ),
        read: (map['read'] as bool?) ?? true,
      );

  static List<ChatMessage> decodeList(String source) {
    final raw = jsonDecode(source) as List<dynamic>;
    return raw.map((e) => ChatMessage.fromMap(e as Map<String, dynamic>)).toList();
  }

  static String encodeList(List<ChatMessage> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList());
}

class ChatThreadSummary {
  final String peerUri;
  final String lastBody;
  final DateTime lastAt;
  final int unread;
  final MessageDirection lastDirection;

  const ChatThreadSummary({
    required this.peerUri,
    required this.lastBody,
    required this.lastAt,
    required this.unread,
    required this.lastDirection,
  });
}
