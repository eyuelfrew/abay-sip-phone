import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/sip_account.dart';
import '../../providers/account_provider.dart';
import '../../services/sip_service.dart';
import 'account_edit_screen.dart';

/// Per-account settings (Zoiper-like): credentials overview + advanced options.
class AccountSettingsScreen extends StatefulWidget {
  final SipAccount account;

  const AccountSettingsScreen({super.key, required this.account});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late SipAccount _account;
  late bool _enabled;
  late bool _srtp;
  late bool _ice;
  late bool _autoAnswer;
  late String _dtmf;
  late int _expires;
  late bool _autoDetect;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _enabled = _account.enabled;
    _srtp = _account.useSrtp;
    _ice = _account.useIce;
    _autoAnswer = _account.autoAnswer;
    _dtmf = _account.dtmfMode;
    _expires = _account.registerExpires;
    _autoDetect = _account.autoDetectTransport;
  }

  Future<void> _persist() async {
    final provider = context.read<AccountProvider>();
    final updated = _account.copyWith(
      enabled: _enabled,
      useSrtp: _srtp,
      useIce: _ice,
      autoAnswer: _autoAnswer,
      dtmfMode: _dtmf,
      registerExpires: _expires,
      autoDetectTransport: _autoDetect,
    );
    _account = await provider.upsert(updated);
    if (mounted) setState(() {});
  }

  Future<void> _editCredentials() async {
    final result = await Navigator.of(context).push<SipAccount>(
      MaterialPageRoute(
        builder: (_) => AccountEditScreen(existing: _account),
      ),
    );
    if (!mounted) return;
    final provider = context.read<AccountProvider>();
    final fresh = provider.accounts.where((a) => a.id == _account.id).toList();
    if (fresh.isNotEmpty) {
      setState(() => _account = fresh.first);
    } else if (result != null) {
      setState(() => _account = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sip = context.watch<SipService>();
    final accounts = context.watch<AccountProvider>();
    final isActive = accounts.activeAccountId == _account.id;
    final isReg = isActive &&
        sip.registrationState == RegistrationState.registered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account settings'),
        actions: [
          IconButton(
            tooltip: 'Edit credentials',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editCredentials,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isReg
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.warning.withOpacity(0.15),
                          child: Icon(
                            isReg ? Icons.verified : Icons.sync_problem,
                            color: isReg ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _account.displayName.isEmpty
                                    ? _account.username
                                    : _account.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_account.username}@${_account.effectiveDomain}',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(
                      label: 'Server',
                      value: _account.host.isEmpty ? '—' : _account.host,
                    ),
                    _InfoRow(
                      label: 'Transport',
                      value:
                          '${_account.transport == SipTransport.tls ? 'WSS' : 'WS'} · ${_account.port}'
                          '${_account.autoDetectTransport ? ' · auto' : ''}',
                    ),
                    _InfoRow(
                      label: 'Status',
                      value: isReg
                          ? 'Registered'
                          : (isActive
                              ? sip.registrationStatus
                              : 'Not active account'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final provider = context.read<AccountProvider>();
                              await provider.setActive(_account.id);
                            },
                            icon: const Icon(Icons.how_to_reg),
                            label: const Text('Register'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isActive
                                ? () =>
                                    context.read<AccountProvider>().unregister()
                                : null,
                            icon: const Icon(Icons.link_off),
                            label: const Text('Unregister'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _SectionHeader('Account'),
          SwitchListTile(
            value: _enabled,
            onChanged: (v) async {
              setState(() => _enabled = v);
              await _persist();
            },
            title: const Text('Enabled'),
            subtitle: const Text('Disabled accounts are not registered'),
            secondary: const Icon(Icons.power_settings_new),
          ),
          SwitchListTile(
            value: _autoDetect,
            onChanged: (v) async {
              setState(() => _autoDetect = v);
              await _persist();
            },
            title: const Text('Auto-detect transport'),
            subtitle: const Text(
              'Scan server for open WSS/WS ports (Zoiper-style)',
            ),
            secondary: const Icon(Icons.radar),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Register expiry'),
            subtitle: Text('$_expires seconds'),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: _expires.toDouble().clamp(60, 3600),
                min: 60,
                max: 3600,
                divisions: 12,
                label: '$_expires s',
                onChanged: (v) => setState(() => _expires = v.round()),
                onChangeEnd: (_) => _persist(),
              ),
            ),
          ),
          const _SectionHeader('Media & security'),
          SwitchListTile(
            value: _srtp,
            onChanged: (v) async {
              setState(() => _srtp = v);
              await _persist();
            },
            title: const Text('SRTP'),
            subtitle: const Text('Encrypt media when PBX supports it'),
            secondary: const Icon(Icons.enhanced_encryption_outlined),
          ),
          SwitchListTile(
            value: _ice,
            onChanged: (v) async {
              setState(() => _ice = v);
              await _persist();
            },
            title: const Text('ICE / STUN'),
            subtitle: const Text('NAT traversal for remote clients'),
            secondary: const Icon(Icons.cell_tower),
          ),
          SwitchListTile(
            value: _autoAnswer,
            onChanged: (v) async {
              setState(() => _autoAnswer = v);
              await _persist();
            },
            title: const Text('Auto-answer'),
            subtitle: const Text('Answer incoming calls automatically'),
            secondary: const Icon(Icons.phone_in_talk),
          ),
          ListTile(
            leading: const Icon(Icons.dialpad),
            title: const Text('DTMF mode'),
            trailing: DropdownButton<String>(
              value: _dtmf,
              items: [
                for (final mode in AppConstants.dtmfModes)
                  DropdownMenuItem(value: mode, child: Text(mode)),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _dtmf = v);
                await _persist();
              },
            ),
          ),
          const _SectionHeader('Danger zone'),
          ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.danger),
            title: Text(
              'Delete account',
              style: TextStyle(color: AppColors.danger),
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete account?'),
                  content: Text('Remove ${_account.username} from Abay?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              await context.read<AccountProvider>().remove(_account.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
