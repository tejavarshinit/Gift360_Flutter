class ProfileVerification {
  final bool emailVerified;
  final bool locationVerified;

  /// Server-derived: `emailVerified && locationVerified`. Never computed here.
  final bool verified;

  const ProfileVerification({
    required this.emailVerified,
    required this.locationVerified,
    required this.verified,
  });

  factory ProfileVerification.fromJson(Map<String, dynamic> json) {
    return ProfileVerification(
      emailVerified: json['emailVerified'] == true,
      locationVerified: json['locationVerified'] == true,
      verified: json['verified'] == true,
    );
  }
}
