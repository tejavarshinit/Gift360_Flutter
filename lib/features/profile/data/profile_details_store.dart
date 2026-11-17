import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/auth/data/models/auth_user.dart';

/// Local profile fields collected after login (name / email / gender / DOB).
/// Mobile stays on [AuthUser] from the verified OTP login.
class ProfileDetails {
  final String name;
  final String email;
  final String gender;
  final String dateOfBirth; // yyyy-MM-dd

  const ProfileDetails({
    this.name = '',
    this.email = '',
    this.gender = '',
    this.dateOfBirth = '',
  });

  bool get isComplete =>
      name.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      gender.trim().isNotEmpty &&
      dateOfBirth.trim().isNotEmpty;

  ProfileDetails copyWith({
    String? name,
    String? email,
    String? gender,
    String? dateOfBirth,
  }) {
    return ProfileDetails(
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'gender': gender,
        'dateOfBirth': dateOfBirth,
      };

  factory ProfileDetails.fromJson(Map<String, dynamic> json) {
    return ProfileDetails(
      name: (json['name'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      gender: (json['gender'] as String?)?.trim() ?? '',
      dateOfBirth: (json['dateOfBirth'] as String?)?.trim() ?? '',
    );
  }
}

class ProfileDetailsStore {
  ProfileDetailsStore._();

  static String _key(String clientId) => 'profile_details_$clientId';

  static Future<ProfileDetails> load(AuthUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(user.clientId));
      if (raw == null || raw.isEmpty) {
        return ProfileDetails(
          name: user.name.trim(),
          email: user.email.trim(),
        );
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return ProfileDetails(name: user.name, email: user.email);
      }
      final stored = ProfileDetails.fromJson(decoded);
      return stored.copyWith(
        name: stored.name.isNotEmpty ? stored.name : user.name,
        email: stored.email.isNotEmpty ? stored.email : user.email,
      );
    } catch (_) {
      return ProfileDetails(name: user.name, email: user.email);
    }
  }

  static Future<void> save(AuthUser user, ProfileDetails details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(user.clientId), jsonEncode(details.toJson()));
    // Keep legacy displayName in sync with the account header.
    if (details.name.trim().isNotEmpty) {
      await prefs.setString('displayName', details.name.trim());
    }
  }

  static Future<bool> isIncomplete(AuthUser user) async {
    final details = await load(user);
    return !details.isComplete;
  }
}
