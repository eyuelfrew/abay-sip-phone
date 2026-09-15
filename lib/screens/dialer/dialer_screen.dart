import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/contact_entry.dart';
import '../../providers/account_provider.dart';
import '../../providers/contact_provider.dart';
import '../../services/sip_service.dart';
import '../calls/active_call_screen.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final _controller = TextEditingController();
  bool _showLetters = false;

  static const _keys = [
    ('1', ''),
    ('2', 'ABC'),
    ('3', 'DEF'),
    ('4', 'GHI'),
    ('5', 'JKL'),
    ('6', 'MNO'),
    ('7', 'PQRS'),
    ('8', 'TUV'),
    ('9', 'WXYZ'),
    ('*', ''),
    ('0', '+'),
    ('#', ''),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tap(String digit) {
    final text = _controller.text;
    // Limit length to something sane for SIP user part.
    if (text.length >= 64) return;
    _controller.text = text + digit;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  void _backspace() {
    final text = _controller.text;
    if (text.isEmpty) return;
    _controller.text = text.substring(0, text.length - 1);
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  Future<void> _call() async {
    final target = _controller.text.trim();
    if (target.isEmpty) return;
    final sip = context.read<SipService>();
    final accounts = context.read<AccountProvider>();
    if (!sip.isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register a SIP account first')),
      );
      return;
    }
    await sip.makeCall(target);
    if (!mounted) return;
    await ActiveCallScreen.open(context);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactProvider>();
    final sip = context.watch<SipService>();
    final query = _controller.text.trim();
    final suggestions = query.isEmpty
        ? const <ContactEntry>[]
        : contacts.search(query).take(4).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Abay'),
        actions: [
          IconButton(
            tooltip: 'Contact matches',
            onPressed: () => setState(() => _showLetters = !_showLetters),
            icon: Icon(_showLetters ? Icons.abc : Icons.dialpad),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _controller,
              readOnly: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: 'Enter number or SIP URI',
                hintStyle: TextStyle(
                  fontSize: 20,
                  color: Theme.of(context).hintColor,
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _backspace,
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (suggestions.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = suggestions[i];
                  return ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        Formatters.initials(c.name),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    label: Text(c.name),
                    onPressed: () {
                      final target = Formatters.prettyUri(c.sipUri);
                      _controller.text = target;
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 14,
                childAspectRatio: 1.35,
              ),
              itemCount: _keys.length,
              itemBuilder: (context, i) {
                final (digit, letters) = _keys[i];
                return _KeypadKey(
                  digit: digit,
                  letters: _showLetters || letters.isNotEmpty ? letters : '',
                  onTap: () => _tap(digit),
                  onLongPress: digit == '0' ? () => _tap('+') : null,
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _controller.text.trim().isEmpty ? null : _call,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    icon: const Icon(Icons.call),
                    label: Text(
                      sip.isRegistered ? 'Call' : 'Call (offline)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: AppColors.dangerSoft,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _controller.text.isEmpty ? null : () {
                      _controller.clear();
                      setState(() {});
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(Icons.close, color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  final String digit;
  final String letters;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _KeypadKey({
    required this.digit,
    required this.letters,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                digit,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
