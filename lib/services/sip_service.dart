import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart' hide RegistrationState;
import 'package:sip_ua/sip_ua.dart' as sip_ua show RegistrationState;

import 'call_platform.dart';
import '../core/utils/formatters.dart';
import '../models/sip_account.dart';

enum RegistrationState {
  none,
  connecting,
  registered,
  failed,
  unregistered,
}

enum AbayCallState {
  idle,
  connecting,
  ringing,
  confirmed,
  held,
  ended,
  failed,
}

class ActiveCallInfo {
  final String callId;
  final String remoteUri;
  final String displayName;
  final bool incoming;
  final bool video;
  final AbayCallState state;
  final DateTime startedAt;
  final bool muted;
  final bool onHold;
  final bool speaker;
  final Duration elapsed;

  const ActiveCallInfo({
    required this.callId,
    required this.remoteUri,
    this.displayName = '',
    required this.incoming,
    this.video = false,
    required this.state,
    required this.startedAt,
    this.muted = false,
    this.onHold = false,
    this.speaker = false,
    this.elapsed = Duration.zero,
  });

  ActiveCallInfo copyWith({
    AbayCallState? state,
    bool? muted,
    bool? onHold,
    bool? speaker,
    Duration? elapsed,
    String? displayName,
  }) {
    return ActiveCallInfo(
      callId: callId,
      remoteUri: remoteUri,
      displayName: displayName ?? this.displayName,
      incoming: incoming,
      video: video,
      state: state ?? this.state,
      startedAt: startedAt,
      muted: muted ?? this.muted,
      onHold: onHold ?? this.onHold,
      speaker: speaker ?? this.speaker,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

class IncomingCallInfo {
  final String callId;
  final String remoteUri;
  final String displayName;
  final bool video;

  const IncomingCallInfo({
    required this.callId,
    required this.remoteUri,
    this.displayName = '',
    this.video = false,
  });
}

/// Thin wrapper around sip_ua (WebRTC) with Abay domain events.
/// For native PJSIP (classic TLS/RTP), upgrade Flutter and swap the backend.
class SipService extends ChangeNotifier {
  SIPUAHelper? _helper;
  SipAccount? _account;
  RegistrationState _regState = RegistrationState.none;
  String _regStatus = '';
  ActiveCallInfo? _active;
  IncomingCallInfo? _incoming;
  final Map<String, Call> _calls = {};
  Timer? _tick;
  bool _muted = false;
  bool _onHold = false;
  bool _speaker = false;
  bool _transportUp = false;
  Timer? _connectWatchdog;
  bool _registering = false;

  final _regController = StreamController<RegistrationState>.broadcast();
  final _regStatusController = StreamController<String>.broadcast();
  final _activeController = StreamController<ActiveCallInfo?>.broadcast();
  final _incomingController = StreamController<IncomingCallInfo?>.broadcast();
  final _dtmfController = StreamController<String>.broadcast();
  final _messageController =
      StreamController<(String from, String body)>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<RegistrationState> get registrationStream => _regController.stream;
  Stream<String> get registrationStatusStream => _regStatusController.stream;
  Stream<ActiveCallInfo?> get activeCallStream => _activeController.stream;
  Stream<IncomingCallInfo?> get incomingCallStream => _incomingController.stream;
  Stream<String> get dtmfStream => _dtmfController.stream;
  Stream<(String, String)> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;

  RegistrationState get registrationState => _regState;
  String get registrationStatus => _regStatus;
  ActiveCallInfo? get activeCall => _active;
  IncomingCallInfo? get incomingCall => _incoming;
  SipAccount? get account => _account;
  SIPUAHelper? get helper => _helper;
  bool get isRegistered => _regState == RegistrationState.registered;
  bool get hasActiveCall => _active != null;

  Future<void> init() async {
    _helper ??= SIPUAHelper();
    _helper!.addSipUaHelperListener(_SipListener(this));
    await CallPlatform.init();
    CallPlatform.onAnswerFromNotification = () => answer();
    CallPlatform.onRejectFromNotification = () => reject();
    await CallPlatform.startService();
  }

  Future<void> register(SipAccount account) async {
    _account = account;
    await init();
    final helper = _helper!;
    _connectWatchdog?.cancel();
    _registering = true;
    _urlIndex = 0;

    try {
      if (helper.registered) {
        await helper.unregister();
      }
      if (helper.connected || helper.connecting) {
        helper.stop();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } catch (_) {}

    final candidates = account.wsUriCandidates;
    // Prefer classic TCP :5060 first when user picked TCP/UDP (Zoiper-style).
    final ordered = <String>[
      if (account.transport == SipTransport.tcp ||
          account.transport == SipTransport.udp)
        'tcp://${account.host}:5060',
      ...candidates,
    ];
    final seen = <String>{};
    final unique = [for (final u in ordered) if (seen.add(u)) u];
    debugPrint('SIP connect candidates: ${unique.join(' | ')}');
    await _startWithTarget(account, unique[_urlIndex], candidates: unique);
  }

  int _urlIndex = 0;

  Future<void> _startWithTarget(
    SipAccount account,
    String target, {
    required List<String> candidates,
  }) async {
    final helper = _helper!;
    final isTcp = target.startsWith('tcp://');
    final label = isTcp ? 'SIP TCP $target' : target;
    _setReg(RegistrationState.connecting, 'Connecting $label…');
    debugPrint('SIP start → $label');

    final settings = UaSettings();
    settings.uri = account.uri;
    settings.authorizationUser =
        account.authUser.isEmpty ? account.username : account.authUser;
    settings.password = account.password;
    settings.displayName = account.displayName;
    settings.userAgent = 'Abay Softphone/1.0';
    settings.register_expires = account.registerExpires;
    settings.sessionTimers = false;
    settings.dtmfMode = account.dtmfMode == 'SIP INFO'
        ? DtmfMode.INFO
        : DtmfMode.RFC2833;
    settings.webSocketSettings.allowBadCertificate = true;
    settings.webSocketSettings.userAgent = 'Abay Softphone/1.0';
    settings.tcpSocketSettings.allowBadCertificate = true;
    settings.connectionRecoveryMaxInterval = 8;
    settings.connectionRecoveryMinInterval = 2;
    settings.iceServers = [
      {'urls': 'stun:stun.l.google.com:19302'},
    ];

    if (isTcp) {
      // Classic SIP over TCP (same idea as Zoiper on :5060).
      settings.transportType = TransportType.TCP;
      settings.host = account.host;
      settings.port = '5060';
    } else {
      settings.transportType = TransportType.WS;
      settings.webSocketUrl = target;
    }

    try {
      await helper.start(settings);
    } catch (e, st) {
      debugPrint('SIP start failed: $e\n$st');
      final msg = e is TypeError
          ? 'SIP stack configuration error (check server/transport)'
          : 'Start failed: $e';
      _setReg(RegistrationState.failed, msg);
      _errorController.add('Unable to start SIP stack: $e');
      _registering = false;
      return;
    }

    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(const Duration(seconds: 6), () async {
      if (!_registering) return;
      if (_regState == RegistrationState.registered) return;
      if (_regState != RegistrationState.connecting) return;

      _urlIndex++;
      if (_urlIndex < candidates.length) {
        debugPrint('SIP timeout on $target → next ${candidates[_urlIndex]}');
        try {
          helper.stop();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _startWithTarget(
          account,
          candidates[_urlIndex],
          candidates: candidates,
        );
        return;
      }

      _setReg(
        RegistrationState.failed,
        'Cannot reach SIP on ${account.host}',
      );
      _errorController.add(
        'Could not connect to ${account.host}.\n'
        'Tried:\n${candidates.map((u) => '• $u').join('\n')}\n\n'
        'Ports:\n'
        '  TCP 5060 — classic SIP (Zoiper)\n'
        '  WSS 8089/ws — WebSocket TLS\n'
        '  WS 8088/ws — WebSocket\n'
        'TLS 5061 is not supported by this stack (plain TCP/WS only).',
      );
      _registering = false;
    });
  }

  Future<void> unregister() async {
    _connectWatchdog?.cancel();
    _registering = false;
    try {
      await _helper?.unregister();
    } catch (_) {}
    _setReg(RegistrationState.unregistered, 'Unregistered');
  }

  Future<void> makeCall(String target, {bool video = false}) async {
    final account = _account;
    final helper = _helper;
    if (helper == null || account == null) {
      _errorController.add('No SIP account is configured');
      return;
    }
    if (!isRegistered && !_transportUp) {
      _errorController.add('Register an account before calling');
      return;
    }
    if (_active != null) {
      _errorController.add('Another call is already active');
      return;
    }

    final uri = Formatters.normalizeTarget(
      target,
      domain: account.effectiveDomain,
    );
    debugPrint('SIP INVITE → $uri via ${account.wsUri}');
    // Set active immediately so the call UI can open without waiting for SIP events.
    _active = ActiveCallInfo(
      callId: 'pending',
      remoteUri: Formatters.prettyUri(uri),
      displayName: Formatters.prettyUri(uri),
      incoming: false,
      state: AbayCallState.connecting,
      startedAt: DateTime.now(),
    );
    _pushActive();
    try {
      final ok = await helper.call(uri, voiceOnly: !video);
      if (!ok) {
        _active = null;
        _pushActive();
        _errorController.add('Unable to start call');
      }
    } catch (e) {
      _active = null;
      _pushActive();
      _errorController.add('Call failed: $e');
    }
  }

  Future<void> answer({bool video = false}) async {
    final incoming = _incoming;
    if (incoming == null) return;
    final call = _calls[incoming.callId];
    if (call == null) return;
    // Promote to active immediately so ActiveCallScreen has data.
    _active = ActiveCallInfo(
      callId: incoming.callId,
      remoteUri: incoming.remoteUri,
      displayName: incoming.displayName,
      incoming: true,
      state: AbayCallState.confirmed,
      startedAt: DateTime.now(),
    );
    _incoming = null;
    _pushIncoming();
    _pushActive();
    try {
      call.answer({'mediaConstraints': _mediaConstraints(!video)});
    } catch (e) {
      _errorController.add('Answer failed: $e');
    }
  }

  Map<String, dynamic> _mediaConstraints(bool voiceOnly) {
    return {
      'audio': true,
      'video': voiceOnly
          ? false
          : {
              'facingMode': 'user',
            },
    };
  }

  Future<void> hangup() async {
    final active = _active;
    if (active == null) return;
    final call = _calls[active.callId];
    try {
      call?.hangup();
    } catch (_) {}
  }

  Future<void> reject() async {
    final incoming = _incoming;
    if (incoming == null) return;
    final call = _calls[incoming.callId];
    try {
      call?.hangup({'status_code': 486});
    } catch (_) {
      try {
        call?.hangup();
      } catch (_) {}
    }
  }

  Future<void> setMute(bool mute) async {
    final call = _currentCall();
    if (call == null) return;
    try {
      if (mute) {
        call.mute(true, false);
      } else {
        call.unmute(true, false);
      }
      _muted = mute;
      _pushActive();
    } catch (e) {
      _errorController.add('Mute failed: $e');
    }
  }

  Future<void> setHold(bool hold) async {
    final call = _currentCall();
    if (call == null) return;
    try {
      if (hold) {
        call.hold();
      } else {
        call.unhold();
      }
      _onHold = hold;
      _pushActive();
    } catch (e) {
      _errorController.add('Hold failed: $e');
    }
  }

  Future<void> setSpeaker(bool enabled) async {
    _speaker = enabled;
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (_) {}
    _pushActive();
  }

  Future<void> sendDtmf(String digit) async {
    final call = _currentCall();
    if (call == null) return;
    try {
      call.sendDTMF(digit);
      _dtmfController.add(digit);
    } catch (e) {
      _errorController.add('DTMF failed: $e');
    }
  }

  Future<void> transfer(String target) async {
    final call = _currentCall();
    if (call == null) return;
    try {
      final uri = Formatters.normalizeTarget(
        target,
        domain: _account?.effectiveDomain,
      );
      call.refer(uri);
    } catch (e) {
      _errorController.add('Transfer failed: $e');
    }
  }

  Future<void> sendMessage(String target, String body) async {
    final account = _account;
    final helper = _helper;
    if (helper == null || account == null) {
      _errorController.add('Register before sending messages');
      return;
    }
    try {
      final uri = Formatters.normalizeTarget(
        target,
        domain: account.effectiveDomain,
      );
      helper.sendMessage(uri, body);
    } catch (e) {
      _errorController.add('MESSAGE failed: $e');
    }
  }

  Call? _currentCall() {
    final active = _active;
    if (active == null) return null;
    return _calls[active.callId];
  }

  void _setReg(RegistrationState state, String status) {
    _regState = state;
    _regStatus = status;
    if (!_regController.isClosed) _regController.add(state);
    if (!_regStatusController.isClosed) _regStatusController.add(status);
    notifyListeners();
  }

  void _pushActive() {
    if (!_activeController.isClosed) _activeController.add(_active);
    notifyListeners();
  }

  void _pushIncoming() {
    if (!_incomingController.isClosed) _incomingController.add(_incoming);
    notifyListeners();
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final active = _active;
      if (active == null) return;
      final elapsed = DateTime.now().difference(active.startedAt);
      _active = active.copyWith(elapsed: elapsed);
      _pushActive();
    });
  }

  void _stopTicker() {
    _tick?.cancel();
    _tick = null;
  }

  void handleRegistration(sip_ua.RegistrationState state) {
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _connectWatchdog?.cancel();
        _registering = false;
        _setReg(RegistrationState.registered, 'Registered');
        CallPlatform.showRegistered(
          'Abay',
          'Registered · ${_account?.username ?? ''}',
        );
        break;
      case RegistrationStateEnum.UNREGISTERED:
        _setReg(RegistrationState.unregistered, 'Unregistered');
        break;
      case RegistrationStateEnum.REGISTRATION_FAILED:
        final reason = state.cause?.reason_phrase ?? 'failed';
        _setReg(RegistrationState.failed, reason);
        break;
      case RegistrationStateEnum.NONE:
      case null:
        break;
    }
  }

  void handleTransport(TransportState state) {
    final up = state.state == TransportStateEnum.CONNECTED;
    _transportUp = up || state.state == TransportStateEnum.CONNECTING;
    switch (state.state) {
      case TransportStateEnum.CONNECTING:
        _setReg(RegistrationState.connecting, 'Connecting transport…');
        break;
      case TransportStateEnum.CONNECTED:
        _setReg(RegistrationState.connecting, 'Transport up — registering…');
        break;
      case TransportStateEnum.DISCONNECTED:
        if (_regState == RegistrationState.registered) {
          _setReg(RegistrationState.unregistered, 'Transport disconnected');
        } else if (_regState == RegistrationState.connecting) {
          _setReg(
            RegistrationState.failed,
            'Transport disconnected — ${_account?.wsUri ?? 'server unreachable'}',
          );
        }
        break;
      case TransportStateEnum.NONE:
        break;
    }
    notifyListeners();
  }

  void handleCall(Call call, CallState state) {
    final id = call.id ?? 'unknown';
    _calls[id] = call;
    final remote = Formatters.prettyUri(call.remote_identity ?? '');
    final display = (call.remote_display_name?.isNotEmpty ?? false)
        ? call.remote_display_name!
        : remote;
    final hasVideo = !(state.audio ?? call.voiceOnly);

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        // Incoming INVITE — direction is reliable; originator may be missing.
        if (call.direction == Direction.incoming) {
          if (_incoming?.callId != id) {
            final info = IncomingCallInfo(
              callId: id,
              remoteUri: remote,
              displayName: display,
              video: hasVideo,
            );
            _incoming = info;
            _calls[id] = call;
            _pushIncoming();
            debugPrint('SIP incoming call from $remote id=$id');
            // Fire-and-forget — never block the SIP event thread.
            unawaited(CallPlatform.bringToForeground());
            unawaited(CallPlatform.showIncoming(
              display.isNotEmpty ? display : 'Incoming call',
              remote,
            ));
          }
          if (_account?.autoAnswer == true) {
            final delay = _account?.autoAnswerDelayMs ?? 0;
            Future<void>.delayed(Duration(milliseconds: delay), () {
              if (_incoming?.callId == id) {
                answer();
              }
            });
          }
        } else {
          _active = ActiveCallInfo(
            callId: id,
            remoteUri: remote,
            displayName: display,
            incoming: false,
            video: hasVideo,
            state: AbayCallState.connecting,
            startedAt: DateTime.now(),
          );
          _pushActive();
        }
        break;
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
        if (_incoming?.callId == id) break;
        if (call.direction == Direction.incoming && _incoming == null) {
          final info = IncomingCallInfo(
            callId: id,
            remoteUri: remote,
            displayName: display,
            video: hasVideo,
          );
          _incoming = info;
          _pushIncoming();
          unawaited(CallPlatform.showIncoming(
            display.isNotEmpty ? display : 'Incoming call',
            remote,
          ));
        } else if (_incoming == null) {
          _active = (_active ??
                  ActiveCallInfo(
                    callId: id,
                    remoteUri: remote,
                    displayName: display,
                    incoming: false,
                    state: AbayCallState.ringing,
                    startedAt: DateTime.now(),
                  ))
              .copyWith(state: AbayCallState.ringing);
          _pushActive();
        }
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.STREAM:
        final hadIncoming = _incoming != null;
        if (hadIncoming) {
          _incoming = null;
          _pushIncoming();
        }
        // Don't restart ticker or spam notifications on every STREAM/MUTE event.
        final alreadyUp = _active?.state == AbayCallState.confirmed &&
            _active?.callId == id;
        final started = _active?.startedAt ?? DateTime.now();
        _active = ActiveCallInfo(
          callId: id,
          remoteUri: remote,
          displayName: display,
          incoming: _active?.incoming ?? call.direction == Direction.incoming,
          video: hasVideo,
          state: AbayCallState.confirmed,
          startedAt: started,
          muted: _muted,
          onHold: _onHold,
          speaker: _speaker,
        );
        if (!alreadyUp) {
          CallPlatform.showOngoing(
            display.isNotEmpty ? display : 'On call',
            remote,
          );
          _startTicker();
        }
        _pushActive();
        break;
      case CallStateEnum.HOLD:
        _onHold = true;
        _pushActive();
        break;
      case CallStateEnum.UNHOLD:
        _onHold = false;
        _pushActive();
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _stopTicker();
        _incoming = null;
        _pushIncoming();
        final was = _active;
        _active = null;
        _muted = false;
        _onHold = false;
        _calls.remove(id);
        CallPlatform.clearCallNotifications();
        final who = _account?.username ?? '';
        if (_regState == RegistrationState.registered) {
          CallPlatform.showRegistered(
            'Abay',
            'Registered · $who',
          );
        }
        if (was != null && state.state == CallStateEnum.FAILED) {
          final cause = state.cause?.reason_phrase ?? 'unknown';
          final code = state.cause?.status_code;
          final detail = code != null ? '$code $cause' : cause;
          debugPrint('SIP call failed: $detail');
          if (!_errorController.isClosed) {
            final friendly = switch (code) {
              488 =>
                'Call rejected (488). Endpoint may not be WebRTC-enabled.',
              404 => 'User not found (404).',
              403 => 'Forbidden (403).',
              486 => 'User busy (486).',
              603 => 'Call declined.',
              _ => 'Call failed: $detail',
            };
            _errorController.add(friendly);
          }
        }
        _pushActive();
        break;
      default:
        break;
    }
  }

  void handleMessage(String from, String body) {
    if (!_messageController.isClosed) {
      _messageController.add((from, body));
    }
  }

  void handleError(String message) {
    if (!_errorController.isClosed) _errorController.add(message);
  }

  @override
  void dispose() {
    _connectWatchdog?.cancel();
    _tick?.cancel();
    try {
      _helper?.stop();
    } catch (_) {}
    _regController.close();
    _regStatusController.close();
    _activeController.close();
    _incomingController.close();
    _dtmfController.close();
    _messageController.close();
    _errorController.close();
    super.dispose();
  }
}

class _SipListener implements SipUaHelperListener {
  final SipService service;
  _SipListener(this.service);

  @override
  void callStateChanged(Call call, CallState state) =>
      service.handleCall(call, state);

  @override
  void onNewMessage(SIPMessageRequest msg) {
    final fromUri = msg.message?.remote_identity?.uri;
    final from = fromUri != null
        ? (fromUri.user != null && fromUri.host != null
            ? '${fromUri.user}@${fromUri.host}'
            : fromUri.toString())
        : 'unknown';
    String body = '';
    try {
      final req = msg.request;
      if (req != null && req.body != null) {
        body = req.body.toString();
      }
    } catch (_) {}
    service.handleMessage(from, body);
  }

  @override
  void onNewNotify(Notify ntf) {
    debugPrint('SIP NOTIFY: ${ntf.request}');
  }

  @override
  void onNewReinvite(ReInvite event) {
    debugPrint('SIP RE-INVITE video=${event.hasVideo}');
  }

  @override
  void registrationStateChanged(sip_ua.RegistrationState state) =>
      service.handleRegistration(state);

  @override
  void transportStateChanged(TransportState state) =>
      service.handleTransport(state);
}
