class AppConstants {
  AppConstants._();

  static const String appName = 'Abay';
  static const String appTagline = 'Softphone';
  static const String prefAccounts = 'abay_accounts_v1';
  static const String prefActiveAccount = 'abay_active_account_v1';
  static const String prefCallHistory = 'abay_call_history_v1';
  static const String prefContacts = 'abay_contacts_v1';
  static const String prefMessages = 'abay_messages_v1';
  static const String prefThemeMode = 'abay_theme_mode_v1';
  static const String prefSettings = 'abay_settings_v1';

  static const List<String> transports = ['UDP', 'TCP', 'TLS'];
  static const List<String> codecs = [
    'opus',
    'PCMU',
    'PCMA',
    'G722',
    'GSM',
    'VP8',
    'H264',
  ];
  static const List<String> dtmfModes = ['RFC2833', 'SIP INFO', 'Inband'];

  static const Duration registrationExpiry = Duration(seconds: 600);
  static const Duration inviteTimeout = Duration(seconds: 60);
}
