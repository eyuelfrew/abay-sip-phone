import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/history_provider.dart';
import 'providers/message_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/calls/incoming_call_overlay.dart';
import 'screens/home_shell.dart';
import 'services/sip_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AbayApp extends StatelessWidget {
  const AbayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      navigatorKey: rootNavigatorKey,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  StreamSubscription? _errorSub;
  StreamSubscription? _incomingSub;
  bool _incomingShowing = false;
  String? _shownIncomingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSip(context));
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }

  void _bindSip(BuildContext context) {
    final sip = context.read<SipService>();

    _errorSub = sip.errorStream.listen((message) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
    });

    // Only show the incoming UI once per call. Do NOT auto-open ActiveCallScreen
    // here — that caused double routes and the app freezing.
    _incomingSub = sip.incomingCallStream.listen((incoming) async {
      if (!mounted) return;
      if (incoming == null) {
        _incomingShowing = false;
        _shownIncomingId = null;
        return;
      }
      if (_incomingShowing && _shownIncomingId == incoming.callId) return;
      if (_incomingShowing) return;
      _incomingShowing = true;
      _shownIncomingId = incoming.callId;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) {
        _incomingShowing = false;
        _shownIncomingId = null;
        return;
      }
      try {
        await IncomingCallOverlay.show(ctx, incoming, sip);
      } finally {
        _incomingShowing = false;
        // Keep _shownIncomingId until stream clears so we don't re-show.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<HistoryProvider>();
    context.watch<MessageProvider>();
    return const HomeShell();
  }
}
