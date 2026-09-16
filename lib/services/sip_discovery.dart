import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ProbeStatus { idle, checking, available, unavailable }

enum TransportKind { wss, ws }

class TransportEndpoint {
  final TransportKind kind;
  final int port;
  final ProbeStatus status;
  final String? detail;

  const TransportEndpoint({
    required this.kind,
    required this.port,
    this.status = ProbeStatus.idle,
    this.detail,
  });

  String get label => kind == TransportKind.wss ? 'WSS' : 'WS';
  String get scheme => kind == TransportKind.wss ? 'wss' : 'ws';

  TransportEndpoint copyWith({
    ProbeStatus? status,
    String? detail,
  }) {
    return TransportEndpoint(
      kind: kind,
      port: port,
      status: status ?? this.status,
      detail: detail ?? this.detail,
    );
  }
}

class NetworkStatus {
  final bool wifi;
  final bool mobile;
  final bool ethernet;
  final bool online;

  const NetworkStatus({
    this.wifi = false,
    this.mobile = false,
    this.ethernet = false,
    this.online = false,
  });

  bool get connected => wifi || mobile || ethernet;
}

class DiscoveryResult {
  final NetworkStatus network;
  final bool hostResolved;
  final String? hostError;
  final List<TransportEndpoint> endpoints;
  final TransportEndpoint? best;

  const DiscoveryResult({
    required this.network,
    this.hostResolved = false,
    this.hostError,
    this.endpoints = const [],
    this.best,
  });

  bool get canRegister => network.connected && hostResolved && best != null;
}

/// Probes host reachability and common WS/WSS ports (Zoiper-style auto detect).
class SipDiscoveryService {
  SipDiscoveryService._();

  // Your ports: 5060 classic TCP SIP, 8088 WS, 8089 WSS. (5061 TLS not in sip_ua.)
  static const List<int> wssPorts = [8089];
  static const List<int> wsPorts = [8088, 5060];

  static bool isIpv4(String host) {
    final t = host.trim();
    final parts = t.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static bool isIpv6(String host) {
    final t = host.trim();
    if (!t.contains(':')) return false;
    return InternetAddress.tryParse(t)?.type == InternetAddressType.IPv6;
  }

  static bool isIpHost(String host) => isIpv4(host) || isIpv6(host);

  static Future<NetworkStatus> readNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final wifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      final mobile = results.contains(ConnectivityResult.mobile);
      final other = results.any((r) =>
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.bluetooth ||
          r == ConnectivityResult.other);
      final ethernet = results.contains(ConnectivityResult.ethernet);
      return NetworkStatus(
        wifi: wifi,
        mobile: mobile,
        ethernet: ethernet,
        online: wifi || mobile || ethernet || other,
      );
    } catch (_) {
      return const NetworkStatus();
    }
  }

  static Future<bool> _tcpOpen(String host, int port,
      {Duration timeout = const Duration(milliseconds: 700)}) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<DiscoveryResult> discover(
    String host, {
    void Function(List<TransportEndpoint> endpoints)? onProgress,
  }) async {
    final cleaned = host.trim();
    final network = await readNetwork();
    if (cleaned.isEmpty) {
      return DiscoveryResult(network: network);
    }
    if (cleaned.contains(' ') || cleaned.contains('://')) {
      return DiscoveryResult(
        network: network,
        hostError: 'Enter a hostname or IP (no scheme)',
      );
    }

    final List<TransportEndpoint> endpoints = [
      for (final p in wssPorts)
        TransportEndpoint(kind: TransportKind.wss, port: p),
      for (final p in wsPorts)
        TransportEndpoint(kind: TransportKind.ws, port: p),
    ];
    onProgress?.call(endpoints);

    // DNS / host resolution for domains.
    if (!isIpHost(cleaned)) {
      try {
        final infos = await InternetAddress.lookup(cleaned)
            .timeout(const Duration(seconds: 3));
        if (infos.isEmpty) {
          return DiscoveryResult(
            network: network,
            hostResolved: false,
            hostError: 'Host not found',
            endpoints: endpoints,
          );
        }
      } on SocketException {
        return DiscoveryResult(
          network: network,
          hostResolved: false,
          hostError: 'DNS lookup failed',
          endpoints: endpoints,
        );
      } on TimeoutException {
        return DiscoveryResult(
          network: network,
          hostResolved: false,
          hostError: 'DNS lookup timed out',
          endpoints: endpoints,
        );
      }
    }

    final resolved = <TransportEndpoint>[];
    // Prefer WSS first (secure), then WS. Probe in parallel batches.
    for (final kind in const [TransportKind.wss, TransportKind.ws]) {
      final ports =
          endpoints.where((e) => e.kind == kind).map((e) => e.port).toList();
      final results = await Future.wait([
        for (final port in ports)
          () async {
            // TCP-only: TLS handshake+close makes Asterisk log SSL_shutdown errors.
            final ok = await _tcpOpen(cleaned, port);
            return TransportEndpoint(
              kind: kind,
              port: port,
              status: ok ? ProbeStatus.available : ProbeStatus.unavailable,
              detail: ok ? 'Open' : 'Closed',
            );
          }(),
      ]);
      resolved.addAll(results);
      onProgress?.call([
        ...resolved,
        ...endpoints.where((e) =>
            !resolved.any((r) => r.kind == e.kind && r.port == e.port)),
      ]);
    }

    final available =
        resolved.where((e) => e.status == ProbeStatus.available).toList();
    TransportEndpoint? best;
    if (available.isNotEmpty) {
      best = available.first;
    } else if (network.connected) {
      // Asterisk default WSS WebSocket port + path /ws
      best = TransportEndpoint(
        kind: TransportKind.wss,
        port: 8089,
        status: ProbeStatus.checking,
        detail: 'Using default 8089/ws',
      );
    }

    final openList = available.map((e) => '${e.label}:${e.port}').join(', ');
    debugPrint(
        'SIP discovery $cleaned → ${openList.isEmpty ? 'none' : openList}');

    return DiscoveryResult(
      network: network,
      hostResolved: true,
      endpoints: resolved,
      best: best,
    );
  }
}
