import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionHeader('Appearance'),
          SwitchListTile(
            value: s.darkMode,
            onChanged: (v) => provider.toggleDark(v),
            title: const Text('Dark mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          const _SectionHeader('Calling'),
          SwitchListTile(
            value: s.useSpeakerOnCall,
            onChanged: (v) =>
                provider.update(s.copyWith(useSpeakerOnCall: v)),
            title: const Text('Speaker on call'),
            secondary: const Icon(Icons.volume_up_outlined),
          ),
          SwitchListTile(
            value: s.autoRegisterOnLaunch,
            onChanged: (v) =>
                provider.update(s.copyWith(autoRegisterOnLaunch: v)),
            title: const Text('Auto-register on launch'),
            secondary: const Icon(Icons.sync),
          ),
          SwitchListTile(
            value: s.enableCallHistory,
            onChanged: (v) =>
                provider.update(s.copyWith(enableCallHistory: v)),
            title: const Text('Keep call history'),
            secondary: const Icon(Icons.history),
          ),
          ListTile(
            leading: const Icon(Icons.timelapse),
            title: const Text('Ring duration'),
            subtitle: Text('${s.ringDurationSec} seconds'),
            trailing: SizedBox(
              width: 180,
              child: Slider(
                value: s.ringDurationSec.toDouble().clamp(15, 120),
                min: 15,
                max: 120,
                divisions: 7,
                label: '${s.ringDurationSec}s',
                onChanged: (v) => provider.update(
                  s.copyWith(ringDurationSec: v.round()),
                ),
              ),
            ),
          ),
          const _SectionHeader('Codec preference'),
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Preferred audio codec'),
            trailing: DropdownButton<String>(
              value: s.defaultCodec,
              items: [
                for (final c in const ['opus', 'PCMU', 'PCMA', 'G722', 'GSM'])
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v != null) provider.update(s.copyWith(defaultCodec: v));
              },
            ),
          ),
          const _SectionHeader('Advanced'),
          SwitchListTile(
            value: s.keepAlive,
            onChanged: (v) => provider.update(s.copyWith(keepAlive: v)),
            title: const Text('Keep SIP stack alive'),
            subtitle: const Text('Stay registered in background when possible'),
            secondary: const Icon(Icons.bolt),
          ),
          SwitchListTile(
            value: s.showMissedBadge,
            onChanged: (v) => provider.update(s.copyWith(showMissedBadge: v)),
            title: const Text('Missed-call badge'),
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Abay'),
            subtitle: Text(
              'Version $_version\nOpen standards SIP softphone · ${AppConstants.appTagline}',
            ),
            isThreeLine: true,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Abay registers over WebSocket (WS/WSS) using the SIP over WebSocket transport, '
              'compatible with Asterisk, FreeSWITCH, Kamailio, OpenSIPS, 3CX, and most ITSPs '
              'that expose a WS endpoint.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
