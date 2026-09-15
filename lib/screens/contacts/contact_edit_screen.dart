import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contact_entry.dart';
import '../../providers/contact_provider.dart';

class ContactEditScreen extends StatefulWidget {
  final ContactEntry? existing;
  const ContactEditScreen({super.key, this.existing});

  @override
  State<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends State<ContactEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _uri;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _uri = TextEditingController(text: e?.sipUri ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _uri.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final entry = ContactEntry(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      sipUri: _uri.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      favorite: widget.existing?.favorite ?? false,
      fromDevice: widget.existing?.fromDevice ?? false,
    );
    await context.read<ContactProvider>().upsert(entry);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit contact' : 'New contact')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _uri,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'SIP URI',
                hintText: 'sip:1001@pbx.example.com',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'SIP URI is required';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Add contact'),
            ),
          ],
        ),
      ),
    );
  }
}
