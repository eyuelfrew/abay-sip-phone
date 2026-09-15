import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/contact_entry.dart';
import '../services/storage_service.dart';

class ContactProvider extends ChangeNotifier {
  final List<ContactEntry> _contacts = [];
  bool _loaded = false;

  List<ContactEntry> get contacts {
    final list = List<ContactEntry>.from(_contacts);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<ContactEntry> get favorites =>
      contacts.where((c) => c.favorite).toList(growable: false);

  bool get loaded => _loaded;

  Future<void> load() async {
    _contacts
      ..clear()
      ..addAll(await StorageService.loadContacts());
    if (_contacts.isEmpty) {
      _contacts.addAll(_seed());
      await StorageService.saveContacts(_contacts);
    }
    _loaded = true;
    notifyListeners();
  }

  List<ContactEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return contacts;
    return contacts.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.sipUri.toLowerCase().contains(q) ||
          (c.phone?.contains(q) ?? false);
    }).toList();
  }

  Future<ContactEntry> upsert(ContactEntry entry) async {
    ContactEntry saved;
    if (entry.id.isEmpty) {
      saved = entry.copyWith(id: const Uuid().v4());
      _contacts.add(saved);
    } else {
      final idx = _contacts.indexWhere((e) => e.id == entry.id);
      saved = entry;
      if (idx >= 0) {
        _contacts[idx] = saved;
      } else {
        _contacts.add(saved);
      }
    }
    await StorageService.saveContacts(_contacts);
    notifyListeners();
    return saved;
  }

  Future<void> toggleFavorite(ContactEntry entry) async {
    await upsert(entry.copyWith(favorite: !entry.favorite));
  }

  Future<void> remove(String id) async {
    _contacts.removeWhere((e) => e.id == id);
    await StorageService.saveContacts(_contacts);
    notifyListeners();
  }

  Future<void> importDeviceContacts(List<ContactEntry> items) async {
    for (final item in items) {
      final exists = _contacts.any(
        (c) => c.fromDevice && c.phone == item.phone && c.name == item.name,
      );
      if (!exists) {
        _contacts.add(item.copyWith(id: const Uuid().v4(), fromDevice: true));
      }
    }
    await StorageService.saveContacts(_contacts);
    notifyListeners();
  }

  List<ContactEntry> _seed() => const [
        ContactEntry(
          id: 'seed-1',
          name: 'Front Desk',
          sipUri: 'sip:1001@pbx.local',
          favorite: true,
        ),
        ContactEntry(
          id: 'seed-2',
          name: 'Sales Team',
          sipUri: 'sip:2000@pbx.local',
        ),
        ContactEntry(
          id: 'seed-3',
          name: 'Support Queue',
          sipUri: 'sip:3000@pbx.local',
          favorite: true,
        ),
      ];
}
