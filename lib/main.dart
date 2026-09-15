import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/account_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/history_provider.dart';
import 'providers/message_provider.dart';
import 'providers/settings_provider.dart';
import 'services/sip_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  final sipService = SipService();
  await sipService.init();

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  final accountProvider = AccountProvider(sipService: sipService);
  await accountProvider.load(autoRegister: settingsProvider.settings.autoRegisterOnLaunch);

  final historyProvider = HistoryProvider(sipService: sipService);
  await historyProvider.load();
  historyProvider.attach();

  final contactProvider = ContactProvider();
  await contactProvider.load();

  final messageProvider = MessageProvider(sipService: sipService);
  await messageProvider.load();
  messageProvider.attach();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: historyProvider),
        ChangeNotifierProvider.value(value: contactProvider),
        ChangeNotifierProvider.value(value: messageProvider),
        ChangeNotifierProvider<SipService>.value(value: sipService),
      ],
      child: const AbayApp(),
    ),
  );
}
