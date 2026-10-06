class AuthorizedPickup {
  final String name;
  final String phone;

  const AuthorizedPickup({
    required this.name,
    required this.phone,
  });

  Map<String, String> toMap() => {
        'name': name,
        'phone': phone,
      };

  factory AuthorizedPickup.fromMap(Map<String, dynamic> map) => AuthorizedPickup(
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
      );
}
