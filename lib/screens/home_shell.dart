import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/account_provider.dart';
import '../providers/history_provider.dart';
import '../providers/message_provider.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/contacts/contacts_screen.dart';
import '../screens/dialer/dialer_screen.dart';
import '../screens/history/call_history_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../services/sip_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DialerScreen(),
    CallHistoryScreen(),
    ContactsScreen(),
    MessagesScreen(),
    AccountsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final sip = context.watch<SipService>();
    final history = context.watch<HistoryProvider>();
    final messages = context.watch<MessageProvider>();
    final accounts = context.watch<AccountProvider>();
    final reg = sip.registrationState;
    final unread = messages.threads().fold<int>(0, (a, b) => a + b.unread);

    return Scaffold(
      body: Column(
        children: [
          _StatusRibbon(
            registered: reg == RegistrationState.registered,
            label: _ribbonLabel(reg, sip, accounts.activeAccount?.displayName),
          ),
          Expanded(child: _pages[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dialpad_outlined),
            selectedIcon: Icon(Icons.dialpad),
            label: 'Dialer',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: history.missedCount > 0,
              label: Text('${history.missedCount}'),
              child: const Icon(Icons.history_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: history.missedCount > 0,
              label: Text('${history.missedCount}'),
              child: const Icon(Icons.history),
            ),
            label: 'Recents',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sim_card_outlined),
            selectedIcon: Icon(Icons.sim_card),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }

  String _ribbonLabel(
    RegistrationState reg,
    SipService sip,
    String? name,
  ) {
    final who = (name == null || name.isEmpty) ? 'No account' : name;
    return switch (reg) {
      RegistrationState.registered => 'Registered · $who',
      RegistrationState.connecting => 'Connecting · $who',
      RegistrationState.failed =>
        'Registration failed · ${sip.registrationStatus}',
      RegistrationState.unregistered => 'Unregistered · $who',
      RegistrationState.none => 'Not registered',
    };
  }
}

class _StatusRibbon extends StatelessWidget {
  final bool registered;
  final String label;
  const _StatusRibbon({required this.registered, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = registered ? AppColors.success : AppColors.warning;
    final bg = color.withOpacity(0.12);
    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
