class SponsorProfile {
  const SponsorProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.code,
  });

  final String uid;
  final String displayName;
  final String email;
  final String code;

  factory SponsorProfile.fromUserDoc(String uid, Map<String, dynamic> map) {
    final profile = Map<String, dynamic>.from(map['profile'] as Map? ?? const {});
    return SponsorProfile(
      uid: uid,
      displayName: (profile['displayName'] as String?)?.trim().isNotEmpty == true
          ? profile['displayName'] as String
          : (profile['email'] as String? ?? 'Detox user'),
      email: profile['email'] as String? ?? '',
      code: map['sponsorCode'] as String? ?? '',
    );
  }
}
