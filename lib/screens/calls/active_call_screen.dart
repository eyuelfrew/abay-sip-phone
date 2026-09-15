import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../services/sip_service.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ActiveCallScreen(),
      ),
    );
  }

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  StreamSubscription? _sub;
  final _transferController = TextEditingController();
  bool _showTransfer = false;
  bool _showKeypad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sip = context.read<SipService>();
      _sub = sip.activeCallStream.listen((call) {
        if (call == null && mounted) {
          Navigator.of(context).maybePop();
        }
      });
      // Auto-close if already gone.
      if (sip.activeCall == null && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _transferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sip = context.watch<SipService>();
    final call = sip.activeCall;

    if (call == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = call.displayName.isNotEmpty
        ? call.displayName
        : Formatters.prettyUri(call.remoteUri);
    final elapsed =
        call.state == AbayCallState.confirmed ? call.elapsed : Duration.zero;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.activeCallGradientStart,
              AppColors.activeCallGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    Formatters.initials(name),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.prettyUri(call.remoteUri),
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 10),
                Text(
                  _stateLabel(call),
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.95),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                if (call.state == AbayCallState.confirmed) ...[
                  const SizedBox(height: 6),
                  Text(
                    Formatters.formatDuration(elapsed),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 18,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const Spacer(),
                if (_showKeypad) _InlineKeypad(sip: sip),
                if (_showTransfer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _transferController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Transfer to…',
                              hintStyle: TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final t = _transferController.text.trim();
                            if (t.isEmpty) return;
                            sip.transfer(t);
                            setState(() => _showTransfer = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Transferring to $t')),
                            );
                          },
                          child: const Text('Go'),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 18,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    _RoundAction(
                      icon: call.muted ? Icons.mic_off : Icons.mic,
                      label: 'Mute',
                      active: call.muted,
                      onTap: () => sip.setMute(!call.muted),
                    ),
                    _RoundAction(
                      icon: Icons.pause,
                      label: 'Hold',
                      active: call.onHold,
                      onTap: () => sip.setHold(!call.onHold),
                    ),
                    _RoundAction(
                      icon: call.speaker ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      active: call.speaker,
                      onTap: () => sip.setSpeaker(!call.speaker),
                    ),
                    _RoundAction(
                      icon: Icons.dialpad,
                      label: 'Keypad',
                      active: _showKeypad,
                      onTap: () => setState(() => _showKeypad = !_showKeypad),
                    ),
                    _RoundAction(
                      icon: Icons.swap_calls,
                      label: 'Transfer',
                      active: _showTransfer,
                      onTap: () =>
                          setState(() => _showTransfer = !_showTransfer),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Material(
                  color: AppColors.danger,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => sip.hangup(),
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Icon(Icons.call_end, color: Colors.white, size: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stateLabel(ActiveCallInfo call) {
    return switch (call.state) {
      AbayCallState.connecting => 'Connecting…',
      AbayCallState.ringing => 'Ringing…',
      AbayCallState.confirmed => call.onHold ? 'On hold' : 'In call',
      AbayCallState.held => 'On hold',
      AbayCallState.ended => 'Ended',
      AbayCallState.failed => 'Failed',
      AbayCallState.idle => '',
    };
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.primary : Colors.white.withOpacity(0.12);
    final fg = active ? AppColors.onPrimary : Colors.white;
    return Column(
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: fg, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
        ),
      ],
    );
  }
}

class _InlineKeypad extends StatelessWidget {
  final SipService sip;
  const _InlineKeypad({required this.sip});

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '*',
    '0',
    '#',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final k in _keys)
            InkWell(
              onTap: () => sip.sendDtmf(k),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  k,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
