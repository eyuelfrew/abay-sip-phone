import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/contact_entry.dart';
import '../../providers/contact_provider.dart';
import '../../services/sip_service.dart';
import '../calls/active_call_screen.dart';
import '../messages/chat_screen.dart';
import 'contact_edit_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContactProvider>();
    final contacts = provider.search(_query);
    final favorites = provider.favorites;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Add contact',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactEditScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ContactEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search name, SIP URI, phone',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (_query.isEmpty && favorites.isNotEmpty) ...[
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final c = favorites[i];
                  return SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            Formatters.initials(c.name),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No contacts yet'
                          : 'No matches for "$_query"',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  )
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = contacts[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(Formatters.initials(c.name)),
                        ),
                        title: Text(c.name),
                        subtitle: Text(c.sipUri),
                        trailing: IconButton(
                          icon: Icon(
                            c.favorite ? Icons.star : Icons.star_border,
                            color: c.favorite ? AppColors.warning : null,
                          ),
                          onPressed: () =>
                              context.read<ContactProvider>().toggleFavorite(c),
                        ),
                        onTap: () => _openDetail(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetail(ContactEntry c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.sipUri,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(sheetContext).hintColor,
                      ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await context.read<SipService>().makeCall(c.sipUri);
                    if (!context.mounted) return;
                    await ActiveCallScreen.open(context);
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(peerUri: c.sipUri, peerName: c.name),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContactEditScreen(existing: c),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                if (!c.fromDevice) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.read<ContactProvider>().remove(c.id);
                    },
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
