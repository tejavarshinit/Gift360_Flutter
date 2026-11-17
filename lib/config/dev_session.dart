import 'dart:convert';

import 'package:gift360/features/auth/data/models/auth_user.dart';

/// Local session for the dev flavor only. This token is not signed by the
/// auth service and must never be sent to staging or prod.
String buildDevSessionToken({
  required String mobile,
  String name = 'Dev User',
  String? email,
}) {
  String segment(Object value) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(value)));
    return encoded.replaceAll('=', '');
  }

  final header = segment({'alg': 'none', 'typ': 'JWT'});
  final payload = segment({
    'sub': 'dev-client',
    'userId': 'dev-client',
    'clientId': 'dev-client',
    'name': name,
    'phoneNumber': mobile,
    'email': email ?? '$mobile@dev.gift360.local',
    'env': 'dev',
  });
  return '$header.$payload.dev';
}

AuthUser devAuthUser({
  required String mobile,
  String name = 'Dev User',
  String? email,
}) {
  final token = buildDevSessionToken(mobile: mobile, name: name, email: email);
  return AuthUser(
    name: name,
    email: email ?? '$mobile@dev.gift360.local',
    mobile: mobile,
    token: token,
    clientId: 'dev-client',
  );
}

LoginResponse devLoginResponse(AuthUser user) {
  return LoginResponse(
    success: true,
    token: user.token,
    message: 'Signed in with the dev OTP.',
    userInfo: UserInfo(
      name: user.name,
      email: user.email,
      mobile: user.mobile,
      clientId: user.clientId,
    ),
  );
}
