import 'dart:convert';

class AbaySettings {
  final bool darkMode;
  final bool keepAlive;
  final bool useSpeakerOnCall;
  final bool muteOnIncoming;
  final bool showMissedBadge;
  final bool enableCallHistory;
  final String defaultCodec;
  final String ringtoneAsset;
  final int ringDurationSec;
  final bool autoRegisterOnLaunch;
  final bool compactDialer;
  final String displayNameOverride;

  const AbaySettings({
    this.darkMode = false,
    this.keepAlive = true,
    this.useSpeakerOnCall = false,
    this.muteOnIncoming = false,
    this.showMissedBadge = true,
    this.enableCallHistory = true,
    this.defaultCodec = 'opus',
    this.ringtoneAsset = '',
    this.ringDurationSec = 45,
    this.autoRegisterOnLaunch = true,
    this.compactDialer = false,
    this.displayNameOverride = '',
  });

  AbaySettings copyWith({
    bool? darkMode,
    bool? keepAlive,
    bool? useSpeakerOnCall,
    bool? muteOnIncoming,
    bool? showMissedBadge,
    bool? enableCallHistory,
    String? defaultCodec,
    String? ringtoneAsset,
    int? ringDurationSec,
    bool? autoRegisterOnLaunch,
    bool? compactDialer,
    String? displayNameOverride,
  }) {
    return AbaySettings(
      darkMode: darkMode ?? this.darkMode,
      keepAlive: keepAlive ?? this.keepAlive,
      useSpeakerOnCall: useSpeakerOnCall ?? this.useSpeakerOnCall,
      muteOnIncoming: muteOnIncoming ?? this.muteOnIncoming,
      showMissedBadge: showMissedBadge ?? this.showMissedBadge,
      enableCallHistory: enableCallHistory ?? this.enableCallHistory,
      defaultCodec: defaultCodec ?? this.defaultCodec,
      ringtoneAsset: ringtoneAsset ?? this.ringtoneAsset,
      ringDurationSec: ringDurationSec ?? this.ringDurationSec,
      autoRegisterOnLaunch: autoRegisterOnLaunch ?? this.autoRegisterOnLaunch,
      compactDialer: compactDialer ?? this.compactDialer,
      displayNameOverride: displayNameOverride ?? this.displayNameOverride,
    );
  }

  Map<String, dynamic> toMap() => {
        'darkMode': darkMode,
        'keepAlive': keepAlive,
        'useSpeakerOnCall': useSpeakerOnCall,
        'muteOnIncoming': muteOnIncoming,
        'showMissedBadge': showMissedBadge,
        'enableCallHistory': enableCallHistory,
        'defaultCodec': defaultCodec,
        'ringtoneAsset': ringtoneAsset,
        'ringDurationSec': ringDurationSec,
        'autoRegisterOnLaunch': autoRegisterOnLaunch,
        'compactDialer': compactDialer,
        'displayNameOverride': displayNameOverride,
      };

  factory AbaySettings.fromMap(Map<String, dynamic> map) => AbaySettings(
        darkMode: (map['darkMode'] as bool?) ?? false,
        keepAlive: (map['keepAlive'] as bool?) ?? true,
        useSpeakerOnCall: (map['useSpeakerOnCall'] as bool?) ?? false,
        muteOnIncoming: (map['muteOnIncoming'] as bool?) ?? false,
        showMissedBadge: (map['showMissedBadge'] as bool?) ?? true,
        enableCallHistory: (map['enableCallHistory'] as bool?) ?? true,
        defaultCodec: (map['defaultCodec'] as String?) ?? 'opus',
        ringtoneAsset: (map['ringtoneAsset'] as String?) ?? '',
        ringDurationSec: (map['ringDurationSec'] as int?) ?? 45,
        autoRegisterOnLaunch: (map['autoRegisterOnLaunch'] as bool?) ?? true,
        compactDialer: (map['compactDialer'] as bool?) ?? false,
        displayNameOverride: (map['displayNameOverride'] as String?) ?? '',
      );

  String encode() => jsonEncode(toMap());
  factory AbaySettings.decode(String source) =>
      AbaySettings.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
