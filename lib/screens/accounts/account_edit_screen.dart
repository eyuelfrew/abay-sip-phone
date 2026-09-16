import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/home_nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/sip_account.dart';
import '../../providers/account_provider.dart';
import '../../services/sip_discovery.dart';

/// Zoiper-style SIP registration: username, password, server (IP or domain).
/// Transport/port are auto-detected; advanced options live in the end drawer.
class AccountEditScreen extends StatefulWidget {
  final SipAccount? existing;
  const AccountEditScreen({super.key, this.existing});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _server;
  late final TextEditingController _displayName;
  late final TextEditingController _authUser;
  late final TextEditingController _domain;
  late final TextEditingController _outbound;
  late final TextEditingController _expires;

  bool _obscure = true;
  bool _busy = false;
  bool _probing = false;
  NetworkStatus _network = const NetworkStatus();
  List<TransportEndpoint> _endpoints = const [];
  TransportEndpoint? _selected;
  String? _hostError;
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _username = TextEditingController(text: e?.username ?? '');
    _password = TextEditingController(text: e?.password ?? '');
    _server = TextEditingController(text: e?.host ?? '');
    _displayName = TextEditingController(text: e?.displayName ?? '');
    _authUser = TextEditingController(text: e?.authUser ?? '');
    _domain = TextEditingController(text: e?.domain ?? '');
    _outbound = TextEditingController(text: e?.outboundProxy ?? '');
    _expires = TextEditingController(text: '${e?.registerExpires ?? 600}');
    if (e != null) {
      final kind = e.transport == SipTransport.tls
          ? TransportKind.wss
          : TransportKind.ws;
      _selected = TransportEndpoint(
        kind: kind,
        port: e.port,
        status: ProbeStatus.available,
        detail: 'Saved',
      );
    }
    _server.addListener(_onServerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
    _watchNetwork();
  }

  void _watchNetwork() {
    _netSub = Connectivity().onConnectivityChanged.listen((results) {
      final wifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      final mobile = results.contains(ConnectivityResult.mobile);
      final ethernet = results.contains(ConnectivityResult.ethernet);
      if (!mounted) return;
      setState(() {
        _network = NetworkStatus(
          wifi: wifi,
          mobile: mobile,
          ethernet: ethernet,
          online: wifi || mobile || ethernet || results.isNotEmpty,
        );
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _netSub?.cancel();
    _server.removeListener(_onServerChanged);
    _username.dispose();
    _password.dispose();
    _server.dispose();
    _displayName.dispose();
    _authUser.dispose();
    _domain.dispose();
    _outbound.dispose();
    _expires.dispose();
    super.dispose();
  }

  void _onServerChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _probe);
  }

  Future<void> _probe() async {
    final host = _server.text.trim();
    if (host.isEmpty) {
      setState(() {
        _endpoints = const [];
        _selected = null;
        _hostError = null;
        _probing = false;
      });
      return;
    }
    // Probe hostname only (strip scheme/port/path).
    var probeHost = host
        .replaceFirst(RegExp(r'^(wss?|https?)://', caseSensitive: false), '');
    final slash = probeHost.indexOf('/');
    if (slash >= 0) probeHost = probeHost.substring(0, slash);
    final colon = probeHost.lastIndexOf(':');
    if (colon > 0 && !probeHost.startsWith('[')) {
      final maybePort = int.tryParse(probeHost.substring(colon + 1));
      if (maybePort != null) probeHost = probeHost.substring(0, colon);
    }
    setState(() {
      _probing = true;
      _hostError = null;
      _endpoints = [
        for (final p in SipDiscoveryService.wssPorts)
          TransportEndpoint(
              kind: TransportKind.wss, port: p, status: ProbeStatus.checking),
        for (final p in SipDiscoveryService.wsPorts)
          TransportEndpoint(
              kind: TransportKind.ws, port: p, status: ProbeStatus.checking),
      ];
    });

    final result = await SipDiscoveryService.discover(
      probeHost,
      onProgress: (eps) {
        if (!mounted) return;
        setState(() => _endpoints = eps);
      },
    );
    if (!mounted) return;
    setState(() {
      _network = result.network;
      _hostError = result.hostError;
      _endpoints = result.endpoints;
      _probing = false;
      if (result.best != null) {
        _selected = result.best;
      }
    });
  }

  SipTransport _transportFrom(TransportEndpoint e) =>
      e.kind == TransportKind.wss ? SipTransport.tls : SipTransport.tcp;

  Future<void> _finish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sel = _selected;
    if (sel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an available network transport first'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final provider = context.read<AccountProvider>();
      final draft = widget.existing ?? provider.createDraft();
      final serverRaw = _server.text.trim();
      final parsed = draft.copyWith(server: serverRaw);
      final typedPort = parsed.serverPortHint;
      // Classic SIP ports (Zoiper) are not WebSocket — remap for sip_ua.
      var port = typedPort ?? sel.port;
      if (port == 5061 || port == 5060 || port == 5062) {
        port = sel.kind == TransportKind.wss ? 8089 : 8088;
      }
      if (sel.kind == TransportKind.wss && (port == 8088)) port = 8089;
      if (sel.kind == TransportKind.ws && port == 8089) port = 8088;
      final account = draft.copyWith(
        displayName: _displayName.text.trim().isEmpty
            ? _username.text.trim()
            : _displayName.text.trim(),
        username: _username.text.trim(),
        authUser: _authUser.text.trim().isEmpty
            ? _username.text.trim()
            : _authUser.text.trim(),
        password: _password.text,
        server: serverRaw,
        domain: _domain.text.trim().isEmpty
            ? parsed.host
            : _domain.text.trim(),
        port: port,
        transport: _transportFrom(sel),
        autoDetectTransport: true,
        enabled: true,
        outboundProxy:
            _outbound.text.trim().isEmpty ? null : _outbound.text.trim(),
        registerExpires: int.tryParse(_expires.text.trim()) ?? 600,
      );
      debugPrint('SIP account save → uri=${account.wsUri}');
      final saved = await provider.upsert(account);
      if (!mounted) return;
      await provider.setActive(saved.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connecting ${saved.wsUri}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      // Land on dial pad (home shell first route, dialer tab = 0).
      HomeNav.goDialer();
      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _AdvancedDrawer(
        displayName: _displayName,
        authUser: _authUser,
        domain: _domain,
        outbound: _outbound,
        expires: _expires,
      ),
      appBar: AppBar(
        title: Text(isEdit ? 'Account' : 'Add SIP account'),
        actions: [
          IconButton(
            tooltip: 'Advanced options',
            icon: const Icon(Icons.tune),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Sign in to your PBX',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your extension credentials and server. '
              'Abay detects the best transport automatically — like Zoiper.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _username,
              validator: (v) => Validators.required(v, 'Username'),
              decoration: const InputDecoration(
                labelText: 'Username / extension',
                hintText: '1001',
                prefixIcon: Icon(Icons.person_outline),
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
              controller: _server,
              validator: Validators.host,
              onChanged: (_) {},
              decoration: InputDecoration(
                labelText: 'Server IP or domain',
                hintText: '192.168.1.10  ·  pbx.example.com',
                prefixIcon: const Icon(Icons.dns_outlined),
                suffixIcon: _probing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Re-scan',
                        onPressed: _probe,
                        icon: const Icon(Icons.radar),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            _NetworkPanel(
              network: _network,
              hostError: _hostError,
              endpoints: _endpoints,
              selected: _selected,
              probing: _probing,
              onSelect: (e) => setState(() => _selected = e),
              onRescan: _probe,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.settings_suggest_outlined),
                label: const Text('Advanced options'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _finish,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Save & register' : 'Finish'),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 10),
              Text(
              'Will connect over ${_selected!.label} · port ${_selected!.port}/ws',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Abay uses SIP over WebSocket (Asterisk :8089/ws). Classic SIP :5061 is for Zoiper only.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NetworkPanel extends StatelessWidget {
  final NetworkStatus network;
  final String? hostError;
  final List<TransportEndpoint> endpoints;
  final TransportEndpoint? selected;
  final bool probing;
  final ValueChanged<TransportEndpoint> onSelect;
  final VoidCallback onRescan;

  const _NetworkPanel({
    required this.network,
    required this.hostError,
    required this.endpoints,
    required this.selected,
    required this.probing,
    required this.onSelect,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    final available =
        endpoints.where((e) => e.status == ProbeStatus.available).toList();
    final checking =
        endpoints.where((e) => e.status == ProbeStatus.checking).toList();

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.network_check, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Network',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                if (probing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: 'Wi‑Fi',
                  ok: network.wifi,
                ),
                _Chip(
                  label: 'Mobile data',
                  ok: network.mobile,
                ),
                _Chip(
                  label: 'Internet',
                  ok: network.online,
                ),
                if (hostError != null)
                  _Chip(label: hostError!, ok: false),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Detected transports',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (endpoints.isEmpty)
              Text(
                'Enter a server IP or domain to scan.',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else if (available.isEmpty && checking.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No open WS/WSS ports found. You can still pick a default.',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in const [
                          TransportEndpoint(
                              kind: TransportKind.wss,
                              port: 8089,
                              status: ProbeStatus.idle),
                          TransportEndpoint(
                              kind: TransportKind.ws,
                              port: 8088,
                              status: ProbeStatus.idle),
                          TransportEndpoint(
                              kind: TransportKind.ws,
                              port: 5060,
                              status: ProbeStatus.idle),
                        ])
                          _EndpointTile(
                            endpoint: e,
                            selected: selected?.kind == e.kind &&
                                selected?.port == e.port,
                            fallback: true,
                            onTap: () => onSelect(e),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in available)
                    _EndpointTile(
                      endpoint: e,
                      selected: selected?.kind == e.kind &&
                          selected?.port == e.port,
                      onTap: () => onSelect(e),
                    ),
                ],
              ),
            if (available.isEmpty && !probing && endpoints.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRescan,
                  child: const Text('Scan again'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool ok;
  const _Chip({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline,
              size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  final TransportEndpoint endpoint;
  final bool selected;
  final bool fallback;
  final VoidCallback onTap;

  const _EndpointTile({
    required this.endpoint,
    required this.selected,
    required this.onTap,
    this.fallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final ok = endpoint.status == ProbeStatus.available || fallback;
    final color = selected
        ? AppColors.primary
        : ok
            ? AppColors.success
            : Theme.of(context).hintColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : color.withOpacity(0.35),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              '${endpoint.label} · ${endpoint.port}${fallback ? ' (default)' : ''}',
              style: TextStyle(
                color: selected ? AppColors.primary : null,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedDrawer extends StatelessWidget {
  final TextEditingController displayName;
  final TextEditingController authUser;
  final TextEditingController domain;
  final TextEditingController outbound;
  final TextEditingController expires;

  const _AdvancedDrawer({
    required this.displayName,
    required this.authUser,
    required this.domain,
    required this.outbound,
    required this.expires,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Advanced options',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Optional. Most PBX setups work without changing these.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: displayName,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authUser,
              decoration: const InputDecoration(
                labelText: 'Auth user',
                hintText: 'Defaults to username',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: domain,
              decoration: const InputDecoration(
                labelText: 'SIP domain / realm',
                hintText: 'Defaults to server',
                prefixIcon: Icon(Icons.public),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: outbound,
              decoration: const InputDecoration(
                labelText: 'Outbound proxy',
                hintText: 'sip:proxy.example.com:5060',
                prefixIcon: Icon(Icons.route),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expires,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Register expiry (seconds)',
                hintText: '600',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'DTMF and media options are under Account settings after you finish.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transports scanned: ${SipDiscoveryService.wssPorts.map((p) => 'WSS $p').followedBy(SipDiscoveryService.wsPorts.map((p) => 'WS $p')).join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
