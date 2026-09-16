import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/sip_account.dart';
import '../../providers/account_provider.dart';
import '../../services/sip_service.dart';
import 'account_edit_screen.dart';
import 'account_settings_screen.dart';
import '../settings/settings_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>();
    final sip = context.watch<SipService>();
    final list = accounts.accounts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('SIP Accounts'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: list.isEmpty
          ? _EmptyAccounts(
              onCreate: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountEditScreen()),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final a = list[i];
                final isActive = a.id == accounts.activeAccountId;
                final isReg = isActive &&
                    sip.registrationState == RegistrationState.registered;
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isReg
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.warning.withOpacity(0.15),
                      child: Icon(
                        isReg ? Icons.verified : Icons.sync_problem,
                        color: isReg ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    title: Text(
                      a.displayName.isEmpty ? a.username : a.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${a.username}@${a.effectiveDomain}\n'
                      '${a.transport == SipTransport.tls ? 'WSS' : 'WS'} · ${a.host}:${a.port}'
                      '${a.autoDetectTransport ? ' · auto' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        switch (v) {
                          case 'use':
                            await accounts.setActive(a.id);
                            break;
                          case 'settings':
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AccountSettingsScreen(account: a),
                              ),
                            );
                            break;
                          case 'edit':
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AccountEditScreen(existing: a),
                              ),
                            );
                            break;
                          case 'register':
                            await accounts.setActive(a.id);
                            break;
                          case 'unregister':
                            await accounts.unregister();
                            break;
                          case 'delete':
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete account?'),
                                content: Text(
                                  'Remove ${a.displayName.isEmpty ? a.username : a.displayName} from Abay?',
                                ),
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
                            if (ok == true) await accounts.remove(a.id);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        if (!isActive)
                          const PopupMenuItem(
                              value: 'use', child: Text('Use this account')),
                        const PopupMenuItem(
                            value: 'settings', child: Text('Account settings')),
                        const PopupMenuItem(
                            value: 'edit', child: Text('Re-run setup')),
                        const PopupMenuItem(
                            value: 'register', child: Text('Re-register')),
                        const PopupMenuItem(
                            value: 'unregister', child: Text('Unregister')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AccountSettingsScreen(account: a),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyAccounts({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sim_card_outlined,
              size: 72,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Add your SIP account',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect Abay to your PBX or ITSP — Asterisk, FreeSWITCH, 3CX, Cloud PBX, and more.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create SIP account'),
            ),
          ],
        ),
      ),
    );
  }
}
