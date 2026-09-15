import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/call_history_entry.dart';
import '../services/sip_service.dart';
import '../services/storage_service.dart';

class HistoryProvider extends ChangeNotifier {
  final SipService sipService;
  HistoryProvider({required this.sipService});

  final List<CallHistoryEntry> _items = [];
  StreamSubscription? _activeSub;
  DateTime? _callStart;
  String? _callRemote;
  String? _callName;
  bool _wasIncoming = false;
  bool _loaded = false;

  List<CallHistoryEntry> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;
  int get missedCount => _items.where((e) => e.isMissed).length;

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await StorageService.loadCallHistory());
    _loaded = true;
    notifyListeners();
  }

  void attach() {
    _activeSub = sipService.activeCallStream.listen(_onActive);
    // When a call ends the stream emits null after a non-null call.
  }

  void _onActive(ActiveCallInfo? call) {
    if (call != null) {
      if (call.state == AbayCallState.confirmed && _callStart == null) {
        _callStart = call.startedAt;
        _callRemote = call.remoteUri;
        _callName = call.displayName;
        _wasIncoming = call.incoming;
      } else if (call.state == AbayCallState.connecting ||
          call.state == AbayCallState.ringing) {
        _callStart ??= call.startedAt;
        _callRemote ??= call.remoteUri;
        _callName ??= call.displayName;
        _wasIncoming = call.incoming;
      }
      return;
    }

    // Call ended (null).
    final start = _callStart;
    if (start == null) return;
    final end = DateTime.now();
    final duration = end.difference(start);
    final missed = _wasIncoming && duration.inSeconds < 3;
    final entry = CallHistoryEntry(
      id: const Uuid().v4(),
      remoteUri: _callRemote ?? '',
      remoteName: _callName ?? '',
      direction: missed
          ? CallDirection.missed
          : (_wasIncoming ? CallDirection.incoming : CallDirection.outgoing),
      startedAt: start,
      duration: duration,
      accountId: '',
      accountLabel: '',
    );
    _callStart = null;
    _callRemote = null;
    _callName = null;
    _items.insert(0, entry);
    _trimAndSave();
    notifyListeners();
  }

  Future<void> _trimAndSave() async {
    if (_items.length > 300) {
      _items.removeRange(300, _items.length);
    }
    await StorageService.saveCallHistory(_items);
  }

  Future<void> clearAll() async {
    _items.clear();
    await StorageService.saveCallHistory(_items);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    await StorageService.saveCallHistory(_items);
    notifyListeners();
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    super.dispose();
  }
}
