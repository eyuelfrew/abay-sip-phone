import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../services/sip_service.dart';

class IncomingCallOverlay {
  static void show(
    BuildContext context,
    IncomingCallInfo incoming,
    SipService sip,
  ) {
    final root = Navigator.of(context, rootNavigator: true);
    root.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => IncomingCallScreen(
          incoming: incoming,
          sip: sip,
        ),
      ),
    );
  }
}

class IncomingCallScreen extends StatelessWidget {
  final IncomingCallInfo incoming;
  final SipService sip;

  const IncomingCallScreen({
    super.key,
    required this.incoming,
    required this.sip,
  });

  @override
  Widget build(BuildContext context) {
    final name = incoming.displayName.isNotEmpty
        ? incoming.displayName
        : Formatters.prettyUri(incoming.remoteUri);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1B2B), Color(0xFF1B4A4A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'Incoming call',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                  Formatters.initials(name),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                Formatters.prettyUri(incoming.remoteUri),
                style: const TextStyle(color: Colors.white60),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BigCallButton(
                      color: AppColors.danger,
                      icon: Icons.call_end,
                      label: 'Decline',
                      onTap: () {
                        sip.reject();
                        Navigator.of(context).maybePop();
                      },
                    ),
                    _BigCallButton(
                      color: AppColors.success,
                      icon: Icons.call,
                      label: 'Answer',
                      onTap: () {
                        sip.answer();
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigCallButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BigCallButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
