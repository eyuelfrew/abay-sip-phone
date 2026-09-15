import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../models/sip_account.dart';
import '../../providers/account_provider.dart';

class AccountEditScreen extends StatefulWidget {
  final SipAccount? existing;
  const AccountEditScreen({super.key, this.existing});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _authUser;
  late final TextEditingController _password;
  late final TextEditingController _domain;
  late final TextEditingController _server;
  late final TextEditingController _port;
  late final TextEditingController _outbound;
  late final TextEditingController _expires;
  SipTransport _transport = SipTransport.udp;
  String _dtmf = 'RFC2833';
  bool _enabled = true;
  bool _srtp = false;
  bool _ice = false;
  bool _autoAnswer = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _displayName = TextEditingController(text: e?.displayName ?? '');
    _username = TextEditingController(text: e?.username ?? '');
    _authUser = TextEditingController(text: e?.authUser ?? '');
    _password = TextEditingController(text: e?.password ?? '');
    _domain = TextEditingController(text: e?.domain ?? '');
    _server = TextEditingController(text: e?.server ?? '');
    _port = TextEditingController(text: '${e?.port ?? 5060}');
    _outbound = TextEditingController(text: e?.outboundProxy ?? '');
    _expires = TextEditingController(text: '${e?.registerExpires ?? 600}');
    _transport = e?.transport ?? SipTransport.udp;
    _dtmf = e?.dtmfMode ?? 'RFC2833';
    _enabled = e?.enabled ?? true;
    _srtp = e?.useSrtp ?? false;
    _ice = e?.useIce ?? false;
    _autoAnswer = e?.autoAnswer ?? false;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _authUser.dispose();
    _password.dispose();
    _domain.dispose();
    _server.dispose();
    _port.dispose();
    _outbound.dispose();
    _expires.dispose();
    super.dispose();
  }

  Future<void> _save({bool registerAfter = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<AccountProvider>();
    final draft = widget.existing ?? provider.createDraft();
    final account = draft.copyWith(
      displayName: _displayName.text.trim(),
      username: _username.text.trim(),
      authUser: _authUser.text.trim().isEmpty
          ? _username.text.trim()
          : _authUser.text.trim(),
      password: _password.text,
      domain: _domain.text.trim(),
      server: _server.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 5060,
      transport: _transport,
      enabled: _enabled,
      useSrtp: _srtp,
      useIce: _ice,
      outboundProxy:
          _outbound.text.trim().isEmpty ? null : _outbound.text.trim(),
      registerExpires: int.tryParse(_expires.text.trim()) ?? 600,
      dtmfMode: _dtmf,
      autoAnswer: _autoAnswer,
    );
    final saved = await provider.upsert(account);
    if (!mounted) return;
    if (registerAfter) {
      await provider.setActive(saved.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit account' : 'New SIP account'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const Text('Account enabled'),
              subtitle: const Text('Disabled accounts are not registered'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _displayName,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _username,
              validator: (v) => Validators.required(v, 'Username'),
              decoration: const InputDecoration(
                labelText: 'SIP username / extension',
                hintText: '1001',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _authUser,
              decoration: const InputDecoration(
                labelText: 'Auth user (optional)',
                hintText: 'Defaults to username',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              validator: (v) => Validators.required(v, 'Password'),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _domain,
              validator: (v) => Validators.required(v, 'Domain'),
              decoration: const InputDecoration(
                labelText: 'SIP domain / realm',
                hintText: 'pbx.example.com',
                prefixIcon: Icon(Icons.public),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _server,
              validator: Validators.host,
              decoration: const InputDecoration(
                labelText: 'Server / registrar host',
                hintText: 'pbx.example.com or IP',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<SipTransport>(
                    value: _transport,
                    decoration: const InputDecoration(
                      labelText: 'Transport',
                      prefixIcon: Icon(Icons.swap_horiz),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SipTransport.udp,
                        child: Text('UDP'),
                      ),
                      DropdownMenuItem(
                        value: SipTransport.tcp,
                        child: Text('TCP'),
                      ),
                      DropdownMenuItem(
                        value: SipTransport.tls,
                        child: Text('TLS / WSS'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _transport = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    validator: Validators.port,
                    decoration: const InputDecoration(labelText: 'Port'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _outbound,
              decoration: const InputDecoration(
                labelText: 'Outbound proxy (optional)',
                hintText: 'sip:proxy.example.com:5060',
                prefixIcon: Icon(Icons.route),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _expires,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Register expiry (seconds)',
                hintText: '600',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _srtp,
              onChanged: (v) => setState(() => _srtp = v),
              title: const Text('SRTP media encryption'),
              subtitle: const Text('Prefer encrypted audio when PBX supports it'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _ice,
              onChanged: (v) => setState(() => _ice = v),
              title: const Text('ICE / STUN'),
              subtitle: const Text('Helps NAT traversal for remote clients'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _autoAnswer,
              onChanged: (v) => setState(() => _autoAnswer = v),
              title: const Text('Auto-answer'),
              subtitle: const Text('Answer incoming calls automatically'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _dtmf,
              decoration: const InputDecoration(
                labelText: 'DTMF mode',
                prefixIcon: Icon(Icons.dialpad),
              ),
              items: [
                for (final mode in AppConstants.dtmfModes)
                  DropdownMenuItem(value: mode, child: Text(mode)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _dtmf = v);
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => _save(registerAfter: false),
              child: Text(isEdit ? 'Save account' : 'Add account'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _save(registerAfter: true),
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Save & register'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
