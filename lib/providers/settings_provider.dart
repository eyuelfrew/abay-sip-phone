import 'package:flutter/material.dart';

import '../models/abay_settings.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  AbaySettings _settings = const AbaySettings();
  bool _loaded = false;

  AbaySettings get settings => _settings;
  bool get loaded => _loaded;
  bool get darkMode => _settings.darkMode;
  ThemeMode get themeMode => _settings.darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    _settings = await StorageService.loadSettings();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AbaySettings next) async {
    _settings = next;
    notifyListeners();
    await StorageService.saveSettings(next);
  }

  Future<void> toggleDark(bool value) =>
      update(_settings.copyWith(darkMode: value));
}
