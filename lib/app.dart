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
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSip(context));
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

    _incomingSub = sip.incomingCallStream.listen((incoming) {
      if (!mounted) return;
      if (incoming == null) {
        final nav = _navigatorKey.currentState;
        // Pop any incoming route if still open.
        if (nav != null && nav.canPop()) {
          // Only pop if the top is the incoming dialog — we use overlay.
        }
        return;
      }
      IncomingCallOverlay.show(context, incoming, sip);
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep history/message providers alive even if tabs dispose.
    context.watch<HistoryProvider>();
    context.watch<MessageProvider>();
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => const HomeShell(),
      ),
    );
  }
}
