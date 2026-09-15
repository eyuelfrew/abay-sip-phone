import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../providers/message_provider.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final threads = provider.threads();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _startNew(context),
          ),
        ],
      ),
      body: threads.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No SIP messages yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Send a MESSAGE request from a peer URI',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = threads[i];
                final name = Formatters.prettyUri(t.peerUri);
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(Formatters.initials(name)),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    t.lastBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatDateTime(t.lastAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (t.unread > 0) ...[
                        const SizedBox(height: 4),
                        CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            '${t.unread}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(peerUri: t.peerUri, peerName: name),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _startNew(BuildContext context) async {
    final controller = TextEditingController();
    final uri = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New SIP chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Peer URI or extension',
            hintText: '1001 or sip:1001@pbx.example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(dialogContext, v);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (uri == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(peerUri: uri, peerName: Formatters.prettyUri(uri)),
      ),
    );
  }
}
