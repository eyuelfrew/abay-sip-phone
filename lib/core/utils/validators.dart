class Validators {
  Validators._();

  static String? required(String? v, [String label = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? host(String? v) {
    if (v == null || v.trim().isEmpty) return 'Server host is required';
    final t = v.trim();
    if (t.contains(' ')) return 'Host cannot contain spaces';
    return null;
  }

  static String? port(String? v) {
    if (v == null || v.trim().isEmpty) return 'Port is required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 1 || n > 65535) return 'Enter a valid port (1–65535)';
    return null;
  }

  static String? optionalPort(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n < 1 || n > 65535) return 'Enter a valid port (1–65535)';
    return null;
  }
}
