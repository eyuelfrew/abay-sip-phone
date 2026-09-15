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

  const SipAccount({
    required this.id,
    required this.displayName,
    required this.username,
    required this.authUser,
    required this.password,
    required this.domain,
    required this.server,
    this.port = 5060,
    this.transport = SipTransport.udp,
    this.enabled = true,
    this.useSrtp = false,
    this.useIce = false,
    this.outboundProxy,
    this.registerExpires = 600,
    this.dtmfMode = 'RFC2833',
    this.autoAnswer = false,
    this.autoAnswerDelayMs = 0,
  });

  String get uri => 'sip:$username@$domain';
  String get wsUri {
    final scheme = switch (transport) {
      SipTransport.tls => 'wss',
      SipTransport.tcp => 'ws',
      SipTransport.udp => 'ws',
    };
    final wsPort = switch (transport) {
      SipTransport.tls => port == 5060 ? 7443 : port,
      _ => port == 5060 ? 8080 : port,
    };
    // Common WSS/WS PBX endpoints; overridable via server:port.
    final host = server;
    return '$scheme://$host:$wsPort';
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
    );
  }

  String encode() => jsonEncode(toMap());
  factory SipAccount.decode(String source) =>
      SipAccount.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
