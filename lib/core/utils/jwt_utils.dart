import 'dart:convert';

/// Decodes the payload segment of a JWT. Returns null if the token is
/// malformed or not valid JSON.
Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Extracts the client id from a JWT's payload, trying the common claim
/// names the auth backend has used (`userId`, `sub`, `clientId`).
/// Returns null when the token can't be decoded or the claim is missing,
/// empty, or whitespace-only.
String? extractClientIdFromToken(String token) {
  final payload = decodeJwtPayload(token);
  if (payload == null) return null;
  final candidate = payload['userId'] ?? payload['sub'] ?? payload['clientId'];
  if (candidate is! String) return null;
  final trimmed = candidate.trim();
  return trimmed.isEmpty ? null : trimmed;
}
