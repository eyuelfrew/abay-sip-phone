import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart' hide RegistrationState;
import 'package:sip_ua/sip_ua.dart' as sip_ua show RegistrationState;

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

/// Thin wrapper around sip_ua with Abay domain events.
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
  }

  Future<void> register(SipAccount account) async {
    _account = account;
    await init();
    final helper = _helper!;

    try {
      if (helper.registered) {
        await helper.unregister();
      }
      if (helper.connected) {
        helper.stop();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } catch (_) {}

    _setReg(RegistrationState.connecting, 'Connecting…');

    final wsUrl = account.wsUri;
    final settings = UaSettings();
    settings.webSocketUrl = wsUrl;
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
    if (account.useIce) {
      settings.iceServers = [
        {'urls': 'stun:stun.l.google.com:19302'},
      ];
    } else {
      settings.iceServers = [];
    }

    try {
      await helper.start(settings);
    } catch (e) {
      _setReg(RegistrationState.failed, 'Start failed: $e');
      _errorController.add('Unable to start SIP stack: $e');
    }
  }

  Future<void> unregister() async {
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

    final uri = Formatters.normalizeTarget(target, domain: account.domain);
    try {
      final ok = await helper.call(uri, voiceOnly: !video);
      if (!ok) _errorController.add('Unable to start call');
    } catch (e) {
      _errorController.add('Call failed: $e');
    }
  }

  Future<void> answer({bool video = false}) async {
    final incoming = _incoming;
    if (incoming == null) return;
    final call = _calls[incoming.callId];
    if (call == null) return;
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

  Future<void> transfer(String target, {bool attended = false}) async {
    final call = _currentCall();
    final account = _account;
    if (call == null || account == null) return;
    final uri = Formatters.normalizeTarget(target, domain: account.domain);
    try {
      call.refer(uri);
    } catch (e) {
      _errorController.add('Transfer failed: $e');
    }
  }

  Future<void> sendMessage(String target, String body) async {
    final helper = _helper;
    final account = _account;
    if (helper == null || account == null) {
      _errorController.add('No SIP account configured');
      return;
    }
    final uri = Formatters.normalizeTarget(target, domain: account.domain);
    try {
      helper.sendMessage(uri, body);
    } catch (e) {
      _errorController.add('Message failed: $e');
    }
  }

  @override
  void dispose() {
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
        _setReg(RegistrationState.registered, 'Registered');
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
    _transportUp = state.state == TransportStateEnum.CONNECTED ||
        state.state == TransportStateEnum.CONNECTING;
    if (state.state == TransportStateEnum.CONNECTING) {
      _setReg(RegistrationState.connecting, 'Connecting transport…');
    } else if (state.state == TransportStateEnum.DISCONNECTED) {
      if (_regState == RegistrationState.registered) {
        _setReg(RegistrationState.unregistered, 'Transport disconnected');
      }
    }
    notifyListeners();
  }

  void handleCall(Call call, CallState state) {
    final id = call.id ?? 'unknown';
    _calls[id] = call;
    final remote = Formatters.prettyUri(call.remote_identity ?? '');
    final display =
        (call.remote_display_name?.isNotEmpty ?? false)
            ? call.remote_display_name!
            : remote;
    final isRemote = state.originator == Originator.remote;
    final hasVideo = !(state.audio ?? call.voiceOnly);

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        if (isRemote && call.direction == Direction.incoming) {
          _incoming = IncomingCallInfo(
            callId: id,
            remoteUri: remote,
            displayName: display,
            video: hasVideo,
          );
          _pushIncoming();
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
        if (_incoming?.callId != id) {
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
        _incoming = null;
        _pushIncoming();
        final started = _active?.startedAt ?? DateTime.now();
        _active = ActiveCallInfo(
          callId: id,
          remoteUri: remote,
          displayName: display,
          incoming: call.direction == Direction.incoming,
          video: hasVideo,
          state: AbayCallState.confirmed,
          startedAt: started,
          muted: _muted,
          onHold: _onHold,
          speaker: _speaker,
        );
        _startTicker();
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
        if (was != null && state.state == CallStateEnum.FAILED) {
          final cause = state.cause?.reason_phrase ?? 'unknown';
          if (!_errorController.isClosed) {
            _errorController.add('Call failed: $cause');
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
