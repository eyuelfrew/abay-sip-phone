import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/abay_settings.dart';
import '../models/call_history_entry.dart';
import '../models/chat_message.dart';
import '../models/contact_entry.dart';
import '../models/sip_account.dart';

class StorageService {
  StorageService._();

  static Future<List<SipAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefAccounts);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SipAccount.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAccounts(List<SipAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefAccounts,
      jsonEncode(accounts.map((e) => e.toMap()).toList()),
    );
  }

  static Future<String?> loadActiveAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefActiveAccount);
  }

  static Future<void> saveActiveAccountId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefActiveAccount, id);
  }

  static Future<List<CallHistoryEntry>> loadCallHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefCallHistory);
    if (raw == null || raw.isEmpty) return [];
    return CallHistoryEntry.decodeList(raw);
  }

  static Future<void> saveCallHistory(List<CallHistoryEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefCallHistory, CallHistoryEntry.encodeList(items));
  }

  static Future<List<ContactEntry>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefContacts);
    if (raw == null || raw.isEmpty) return [];
    return ContactEntry.decodeList(raw);
  }

  static Future<void> saveContacts(List<ContactEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefContacts, ContactEntry.encodeList(items));
  }

  static Future<List<ChatMessage>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefMessages);
    if (raw == null || raw.isEmpty) return [];
    return ChatMessage.decodeList(raw);
  }

  static Future<void> saveMessages(List<ChatMessage> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefMessages, ChatMessage.encodeList(items));
  }

  static Future<AbaySettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefSettings);
    if (raw == null || raw.isEmpty) return const AbaySettings();
    return AbaySettings.decode(raw);
  }

  static Future<void> saveSettings(AbaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefSettings, settings.encode());
  }
}
