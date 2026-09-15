import 'dart:convert';

class ContactEntry {
  final String id;
  final String name;
  final String sipUri;
  final String? phone;
  final String? email;
  final bool favorite;
  final bool fromDevice;

  const ContactEntry({
    required this.id,
    required this.name,
    required this.sipUri,
    this.phone,
    this.email,
    this.favorite = false,
    this.fromDevice = false,
  });

  ContactEntry copyWith({
    String? id,
    String? name,
    String? sipUri,
    String? phone,
    String? email,
    bool? favorite,
    bool? fromDevice,
  }) {
    return ContactEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      sipUri: sipUri ?? this.sipUri,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      favorite: favorite ?? this.favorite,
      fromDevice: fromDevice ?? this.fromDevice,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sipUri': sipUri,
        'phone': phone,
        'email': email,
        'favorite': favorite,
        'fromDevice': fromDevice,
      };

  factory ContactEntry.fromMap(Map<String, dynamic> map) => ContactEntry(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        sipUri: (map['sipUri'] as String?) ?? '',
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        favorite: (map['favorite'] as bool?) ?? false,
        fromDevice: (map['fromDevice'] as bool?) ?? false,
      );

  static List<ContactEntry> decodeList(String source) {
    final raw = jsonDecode(source) as List<dynamic>;
    return raw
        .map((e) => ContactEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<ContactEntry> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList());
}
