import 'dart:convert';

enum CallDirection { incoming, outgoing, missed }

class CallHistoryEntry {
  final String id;
  final String remoteUri;
  final String remoteName;
  final CallDirection direction;
  final DateTime startedAt;
  final Duration duration;
  final String accountId;
  final String accountLabel;
  final bool hadVideo;
  final String? hangupCause;

  const CallHistoryEntry({
    required this.id,
    required this.remoteUri,
    this.remoteName = '',
    required this.direction,
    required this.startedAt,
    this.duration = Duration.zero,
    required this.accountId,
    this.accountLabel = '',
    this.hadVideo = false,
    this.hangupCause,
  });

  bool get isMissed => direction == CallDirection.missed;

  Map<String, dynamic> toMap() => {
        'id': id,
        'remoteUri': remoteUri,
        'remoteName': remoteName,
        'direction': direction.name,
        'startedAt': startedAt.toIso8601String(),
        'duration': duration.inSeconds,
        'accountId': accountId,
        'accountLabel': accountLabel,
        'hadVideo': hadVideo,
        'hangupCause': hangupCause,
      };

  factory CallHistoryEntry.fromMap(Map<String, dynamic> map) {
    return CallHistoryEntry(
      id: map['id'] as String,
      remoteUri: (map['remoteUri'] as String?) ?? '',
      remoteName: (map['remoteName'] as String?) ?? '',
      direction: CallDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => CallDirection.outgoing,
      ),
      startedAt:
          DateTime.tryParse((map['startedAt'] as String?) ?? '') ?? DateTime.now(),
      duration: Duration(seconds: (map['duration'] as int?) ?? 0),
      accountId: (map['accountId'] as String?) ?? '',
      accountLabel: (map['accountLabel'] as String?) ?? '',
      hadVideo: (map['hadVideo'] as bool?) ?? false,
      hangupCause: map['hangupCause'] as String?,
    );
  }

  static List<CallHistoryEntry> decodeList(String source) {
    final raw = jsonDecode(source) as List<dynamic>;
    return raw
        .map((e) => CallHistoryEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<CallHistoryEntry> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList());
}
