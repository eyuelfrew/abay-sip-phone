import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/call_history_entry.dart';
import '../../providers/history_provider.dart';
import '../../services/sip_service.dart';
import '../calls/active_call_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  String _filter = 'All'; // All | Missed | Outgoing | Incoming

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final items = history.items.where((e) {
      switch (_filter) {
        case 'Missed':
          return e.isMissed;
        case 'Outgoing':
          return e.direction == CallDirection.outgoing;
        case 'Incoming':
          return e.direction == CallDirection.incoming;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Recents'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') {
                history.clearAll();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear history')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All', label: Text('All')),
                ButtonSegment(value: 'Missed', label: Text('Missed')),
                ButtonSegment(value: 'Outgoing', label: Text('Out')),
                ButtonSegment(value: 'Incoming', label: Text('In')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ),
      body: items.isEmpty
          ? const _EmptyRecents()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = items[i];
                final name = e.remoteName.isNotEmpty
                    ? e.remoteName
                    : Formatters.prettyUri(e.remoteUri);
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.dangerSoft,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete, color: AppColors.danger),
                  ),
                  onDismissed: (_) => context.read<HistoryProvider>().remove(e.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _tone(e).withOpacity(0.15),
                      child: Icon(_icon(e), color: _tone(e), size: 20),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: e.isMissed ? AppColors.danger : null,
                      ),
                    ),
                    subtitle: Text(
                      '${Formatters.prettyUri(e.remoteUri)} · ${Formatters.formatDuration(e.duration)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.formatDateTime(e.startedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Icon(Icons.call, size: 16, color: AppColors.primary),
                      ],
                    ),
                    onTap: () async {
                      final sip = context.read<SipService>();
                      await sip.makeCall(e.remoteUri);
                      if (!context.mounted) return;
                      await ActiveCallScreen.open(context);
                    },
                  ),
                );
              },
            ),
    );
  }

  Color _tone(CallHistoryEntry e) {
    if (e.isMissed) return AppColors.danger;
    if (e.direction == CallDirection.outgoing) return AppColors.info;
    return AppColors.success;
  }

  IconData _icon(CallHistoryEntry e) {
    if (e.isMissed) return Icons.call_missed;
    if (e.direction == CallDirection.outgoing) return Icons.call_made;
    return Icons.call_received;
  }
}

class _EmptyRecents extends StatelessWidget {
  const _EmptyRecents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          Text(
            'No recent calls',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Place a call from the Dialer tab',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ],
      ),
    );
  }
}
