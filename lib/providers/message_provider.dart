import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/sip_service.dart';
import '../services/storage_service.dart';

class MessageProvider extends ChangeNotifier {
  final SipService sipService;
  MessageProvider({required this.sipService});

  final List<ChatMessage> _messages = [];
  StreamSubscription? _sub;
  bool _loaded = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loaded => _loaded;

  Future<void> load() async {
    _messages
      ..clear()
      ..addAll(await StorageService.loadMessages());
    _loaded = true;
    notifyListeners();
  }

  void attach() {
    _sub = sipService.messageStream.listen((event) {
      final (from, body) = event;
      if (body.isEmpty) return;
      _messages.add(ChatMessage(
        id: const Uuid().v4(),
        peerUri: from,
        body: body,
        at: DateTime.now(),
        direction: MessageDirection.inbound,
        read: false,
      ));
      _persist();
      notifyListeners();
    });
  }

  List<ChatThreadSummary> threads() {
    final map = <String, List<ChatMessage>>{};
    for (final m in _messages) {
      final key = m.peerUri.toLowerCase();
      map.putIfAbsent(key, () => []).add(m);
    }
    final result = <ChatThreadSummary>[];
    map.forEach((peer, list) {
      list.sort((a, b) => b.at.compareTo(a.at));
      final last = list.first;
      result.add(ChatThreadSummary(
        peerUri: peer,
        lastBody: last.body,
        lastAt: last.at,
        unread: list.where((e) => !e.read).length,
        lastDirection: last.direction,
      ));
    });
    result.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return result;
  }

  List<ChatMessage> threadMessages(String peerUri) {
    final key = peerUri.toLowerCase();
    final list =
        _messages.where((m) => m.peerUri.toLowerCase() == key).toList();
    list.sort((a, b) => a.at.compareTo(b.at));
    return list;
  }

  Future<void> send(String peerUri, String body) async {
    if (body.trim().isEmpty) return;
    _messages.add(ChatMessage(
      id: const Uuid().v4(),
      peerUri: peerUri,
      body: body.trim(),
      at: DateTime.now(),
      direction: MessageDirection.outbound,
    ));
    _persist();
    notifyListeners();
    await sipService.sendMessage(peerUri, body.trim());
  }

  Future<void> markThreadRead(String peerUri) async {
    final key = peerUri.toLowerCase();
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].peerUri.toLowerCase() == key && !_messages[i].read) {
        _messages[i] = _messages[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _messages.clear();
    _persist();
    notifyListeners();
  }

  void _persist() {
    StorageService.saveMessages(_messages);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
