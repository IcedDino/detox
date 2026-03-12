import 'dart:convert';

class AuthUser {
  const AuthUser({
    this.uid,
    required this.email,
    required this.displayName,
    required this.provider,
    this.phoneNumber,
  });

  final String? uid;
  final String email;
  final String displayName;
  final String provider;
  final String? phoneNumber;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'provider': provider,
        'phoneNumber': phoneNumber,
      };

  String toJson() => jsonEncode(toMap());

  factory AuthUser.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return AuthUser(
      uid: map['uid'] as String?,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      provider: map['provider'] as String? ?? 'email',
      phoneNumber: map['phoneNumber'] as String?,
    );
  }
}
