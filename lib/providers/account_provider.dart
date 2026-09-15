import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/sip_account.dart';
import '../services/sip_service.dart';
import '../services/storage_service.dart';

class AccountProvider extends ChangeNotifier {
  final SipService sipService;

  AccountProvider({required this.sipService});

  final List<SipAccount> _accounts = [];
  String? _activeId;
  bool _loaded = false;

  List<SipAccount> get accounts => List.unmodifiable(_accounts);
  bool get loaded => _loaded;
  bool get hasAccounts => _accounts.isNotEmpty;

  SipAccount? get activeAccount {
    if (_accounts.isEmpty) return null;
    final found = _accounts.where((a) => a.id == _activeId).toList();
    if (found.isNotEmpty) return found.first;
    final enabled = _accounts.where((a) => a.enabled).toList();
    return enabled.isNotEmpty ? enabled.first : _accounts.first;
  }

  String get activeAccountId => activeAccount?.id ?? '';

  Future<void> load({bool autoRegister = false}) async {
    final list = await StorageService.loadAccounts();
    _accounts
      ..clear()
      ..addAll(list);
    _activeId = await StorageService.loadActiveAccountId();
    if (_activeId == null && _accounts.isNotEmpty) {
      _activeId = _accounts.first.id;
      await StorageService.saveActiveAccountId(_activeId!);
    }
    _loaded = true;
    notifyListeners();
    if (autoRegister) {
      await registerActive();
    }
  }

  Future<SipAccount> upsert(SipAccount account) async {
    final idx = _accounts.indexWhere((e) => e.id == account.id);
    SipAccount saved;
    if (idx >= 0) {
      saved = account;
      _accounts[idx] = saved;
    } else {
      saved = account.copyWith(id: account.id.isEmpty ? const Uuid().v4() : account.id);
      _accounts.add(saved);
    }
    if (_activeId == null) _activeId = saved.id;
    await _persist();
    notifyListeners();
    return saved;
  }

  SipAccount createDraft() {
    return SipAccount(
      id: const Uuid().v4(),
      displayName: '',
      username: '',
      authUser: '',
      password: '',
      domain: '',
      server: '',
      port: 5060,
      transport: SipTransport.udp,
    );
  }

  Future<void> remove(String id) async {
    _accounts.removeWhere((e) => e.id == id);
    if (_activeId == id) {
      _activeId = _accounts.isNotEmpty ? _accounts.first.id : null;
      if (_activeId != null) {
        await StorageService.saveActiveAccountId(_activeId!);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    _activeId = id;
    await StorageService.saveActiveAccountId(id);
    notifyListeners();
    await registerActive();
  }

  Future<void> registerActive() async {
    final account = activeAccount;
    if (account == null || !account.enabled) return;
    await sipService.register(account);
    notifyListeners();
  }

  Future<void> unregister() async {
    await sipService.unregister();
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.saveAccounts(_accounts);
  }
}
