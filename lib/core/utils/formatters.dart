class Formatters {
  Formatters._();

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  static String formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (day == today) return 'Today $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
    if (now.difference(dt).inDays < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${names[dt.weekday - 1]} $time';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} $time';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String prettyUri(String? uri) {
    if (uri == null || uri.isEmpty) return '';
    var s = uri;
    s = s.replaceFirst(RegExp(r'^sip:', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^sips:', caseSensitive: false), '');
    final at = s.indexOf('@');
    if (at > 0) s = s.substring(0, at);
    return s;
  }

  static bool looksLikeNumber(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\.\+]'), '');
    return cleaned.isNotEmpty && RegExp(r'^[0-9*#]+$').hasMatch(cleaned);
  }

  static String normalizeTarget(String input, {String? domain}) {
    final t = input.trim();
    if (t.isEmpty) return t;
    if (t.startsWith('sip:') || t.startsWith('sips:')) return t;
    if (t.contains('@')) return 'sip:$t';
    if (domain != null && domain.isNotEmpty) return 'sip:$t@$domain';
    return 'sip:$t';
  }
}
