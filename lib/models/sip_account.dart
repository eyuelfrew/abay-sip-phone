import 'dart:convert';

enum SipTransport { udp, tcp, tls }

class SipAccount {
  final String id;
  final String displayName;
  final String username;
  final String authUser;
  final String password;
  final String domain;
  final String server;
  final int port;
  final SipTransport transport;
  final bool enabled;
  final bool useSrtp;
  final bool useIce;
  final String? outboundProxy;
  final int registerExpires;
  final String dtmfMode;
  final bool autoAnswer;
  final int autoAnswerDelayMs;
  final bool autoDetectTransport;

  const SipAccount({
    required this.id,
    required this.displayName,
    required this.username,
    required this.authUser,
    required this.password,
    required this.domain,
    required this.server,
    this.port = 8089,
    this.transport = SipTransport.tls,
    this.enabled = true,
    this.useSrtp = false,
    this.useIce = false,
    this.outboundProxy,
    this.registerExpires = 600,
    this.dtmfMode = 'RFC2833',
    this.autoAnswer = false,
    this.autoAnswerDelayMs = 0,
    this.autoDetectTransport = true,
  });

  /// Host used for SIP URI / WebSocket — server wins, domain as fallback.
  /// Strips optional port and path (e.g. `pbx.example.com:8089/ws`).
  String get host {
    final s = server.trim().isNotEmpty ? server.trim() : domain.trim();
    return _splitServer(s).host;
  }

  /// Optional WebSocket path. Asterisk always uses `/ws`.
  String get wsPath {
    final p = _splitServer(server.trim()).path;
    if (p.isNotEmpty) return p;
    return '/ws';
  }

  /// Effective WebSocket port — classic SIP ports are remapped for WS.
  int get effectiveWsPort {
    final p = port;
    // 5060/5061 are SIP UDP/TLS (what Zoiper uses). Abay needs HTTP WebSocket.
    if (p == 5061 || p == 5060 || p == 5062) return 8089;
    if (p == 0) return 8089;
    return p;
  }

  /// Port typed in the server field, if any.
  int? get serverPortHint => _splitServer(server.trim()).port;

  /// SIP realm/domain — defaults to server host when domain not set separately.
  String get effectiveDomain {
    final d = domain.trim();
    if (d.isNotEmpty) return d;
    return host;
  }

  bool get isIpHost {
    final h = host;
    if (h.isEmpty) return false;
    final v4 = h.split('.');
    if (v4.length == 4) {
      for (final p in v4) {
        final n = int.tryParse(p);
        if (n == null || n < 0 || n > 255) return false;
      }
      return true;
    }
    return h.contains(':');
  }

  String get uri => 'sip:$username@$effectiveDomain';

  /// Destination URI for dialing (classic SIP).
  String get dialUri => 'sip:$username@$effectiveDomain';

  /// Primary WebSocket URL (SIP over WS/WSS for sip_ua).
  String get wsUri {
    final scheme = transport == SipTransport.tls ? 'wss' : 'ws';
    final port = effectiveWsPort;
    final path = wsPath;
    return '$scheme://$host:$port$path';
  }

  /// Candidates to try in order when the primary URL fails.
  /// Includes classic SIP TCP :5060 and WebSocket :8089/:8088.
  List<String> get wsUriCandidates {
    final h = host;
    final primary = wsUri;
    final list = <String>[
      primary,
      // Classic SIP (Zoiper-style signaling) — sip_ua TCP transport
      'tcp://$h:5060',
      // Asterisk WebSocket
      'wss://$h:8089/ws',
      'ws://$h:8088/ws',
    ];
    final seen = <String>{};
    return [for (final u in list) if (seen.add(u)) u];
  }

  static ({String host, int? port, String path}) _splitServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return (host: '', port: null, path: '');
    s = s.replaceFirst(RegExp(r'^(wss?|https?)://', caseSensitive: false), '');
    var path = '';
    final slash = s.indexOf('/');
    if (slash >= 0) {
      path = s.substring(slash);
      s = s.substring(0, slash);
    }
    if (path.isNotEmpty && !path.startsWith('/')) path = '/$path';
    int? port;
    if (s.startsWith('[')) {
      final end = s.indexOf(']');
      if (end > 0) {
        final rest = s.substring(end + 1);
        if (rest.startsWith(':')) port = int.tryParse(rest.substring(1));
        s = s.substring(0, end + 1);
      }
    } else {
      final parts = s.split(':');
      if (parts.length == 2) {
        final p = int.tryParse(parts[1]);
        if (p != null) {
          port = p;
          s = parts[0];
        }
      }
    }
    return (host: s, port: port, path: path);
  }

  SipAccount copyWith({
    String? id,
    String? displayName,
    String? username,
    String? authUser,
    String? password,
    String? domain,
    String? server,
    int? port,
    SipTransport? transport,
    bool? enabled,
    bool? useSrtp,
    bool? useIce,
    String? outboundProxy,
    int? registerExpires,
    String? dtmfMode,
    bool? autoAnswer,
    int? autoAnswerDelayMs,
    bool? autoDetectTransport,
  }) {
    return SipAccount(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      authUser: authUser ?? this.authUser,
      password: password ?? this.password,
      domain: domain ?? this.domain,
      server: server ?? this.server,
      port: port ?? this.port,
      transport: transport ?? this.transport,
      enabled: enabled ?? this.enabled,
      useSrtp: useSrtp ?? this.useSrtp,
      useIce: useIce ?? this.useIce,
      outboundProxy: outboundProxy ?? this.outboundProxy,
      registerExpires: registerExpires ?? this.registerExpires,
      dtmfMode: dtmfMode ?? this.dtmfMode,
      autoAnswer: autoAnswer ?? this.autoAnswer,
      autoAnswerDelayMs: autoAnswerDelayMs ?? this.autoAnswerDelayMs,
      autoDetectTransport: autoDetectTransport ?? this.autoDetectTransport,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'username': username,
        'authUser': authUser,
        'password': password,
        'domain': domain,
        'server': server,
        'port': port,
        'transport': transport.name,
        'enabled': enabled,
        'useSrtp': useSrtp,
        'useIce': useIce,
        'outboundProxy': outboundProxy,
        'registerExpires': registerExpires,
        'dtmfMode': dtmfMode,
        'autoAnswer': autoAnswer,
        'autoAnswerDelayMs': autoAnswerDelayMs,
        'autoDetectTransport': autoDetectTransport,
      };

  factory SipAccount.fromMap(Map<String, dynamic> map) {
    return SipAccount(
      id: map['id'] as String,
      displayName: (map['displayName'] as String?) ?? '',
      username: (map['username'] as String?) ?? '',
      authUser: (map['authUser'] as String?) ?? (map['username'] as String? ?? ''),
      password: (map['password'] as String?) ?? '',
      domain: (map['domain'] as String?) ?? '',
      server: (map['server'] as String?) ?? '',
      port: (map['port'] as int?) ?? 5060,
      transport: SipTransport.values.firstWhere(
        (e) => e.name == (map['transport'] as String? ?? 'udp'),
        orElse: () => SipTransport.udp,
      ),
      enabled: (map['enabled'] as bool?) ?? true,
      useSrtp: (map['useSrtp'] as bool?) ?? false,
      useIce: (map['useIce'] as bool?) ?? false,
      outboundProxy: map['outboundProxy'] as String?,
      registerExpires: (map['registerExpires'] as int?) ?? 600,
      dtmfMode: (map['dtmfMode'] as String?) ?? 'RFC2833',
      autoAnswer: (map['autoAnswer'] as bool?) ?? false,
      autoAnswerDelayMs: (map['autoAnswerDelayMs'] as int?) ?? 0,
      autoDetectTransport: (map['autoDetectTransport'] as bool?) ?? true,
    );
  }

  String encode() => jsonEncode(toMap());
  factory SipAccount.decode(String source) =>
      SipAccount.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
