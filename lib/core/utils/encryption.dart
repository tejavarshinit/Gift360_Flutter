import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:gift360/config/app_config.dart';

// ── Key/IV normalization ───────────────────────────────────────────────────
// Mirrors React's getKeyBytes()/getIvBytes() in utils/encryption.ts exactly:
// raw UTF-8 bytes, zero-padded if short, truncated if long, to a fixed
// length (32 bytes for AES-256, 16 bytes for the IV). encrypt_lib.Key/IV's
// fromUtf8() constructors require an *exact*-length string, so we build the
// fixed-length byte arrays ourselves instead.
Uint8List _fixedLengthUtf8(String text, int length) {
  final bytes = utf8.encode(text);
  final result = Uint8List(length);
  final copyLen = bytes.length < length ? bytes.length : length;
  result.setRange(0, copyLen, bytes.sublist(0, copyLen));
  return result;
}

encrypt_lib.Key _keyBytes() => encrypt_lib.Key(_fixedLengthUtf8(AppConfig.encryptionKey, 32));
encrypt_lib.IV _ivBytes() => encrypt_lib.IV(_fixedLengthUtf8(AppConfig.encryptionIv, 16));

encrypt_lib.Encrypter _encrypter() => encrypt_lib.Encrypter(
      encrypt_lib.AES(_keyBytes(), mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'),
    );

/// Mirrors React's normalizeBase64() in utils/encryption.ts — payment
/// gateway callback query strings sometimes turn `+` into a space, and
/// some encoders use URL-safe base64 (`-`/`_`); this repairs both plus
/// re-adds the `=` padding a URL strips.
String _normalizeBase64(String value) {
  if (value.isEmpty) return '';
  final sanitized = value.trim().replaceAll(' ', '+').replaceAll('-', '+').replaceAll('_', '/');
  final remainder = sanitized.length % 4;
  if (remainder == 0) return sanitized;
  if (remainder == 2) return '$sanitized==';
  if (remainder == 3) return '$sanitized=';
  return sanitized;
}

/// AES-256-CBC/PKCS7 encrypt, matching the backend/React scheme exactly.
/// Used when *creating* an order reference to hand to the payment gateway.
String encryptOrderRef(String orderNumber, String clientId) {
  final plaintext = '$orderNumber|$clientId';
  final encrypted = _encrypter().encrypt(plaintext, iv: _ivBytes());
  return encrypted.base64;
}

/// AES-256-CBC/PKCS7 decrypt, matching React's `decrypt()` in
/// utils/encryption.ts. Returns null (never throws) if the payload isn't
/// decryptable — callers should treat that as "could not verify".
String? decryptPayload(String encryptedBase64) {
  if (encryptedBase64.isEmpty) return null;
  try {
    final normalized = _normalizeBase64(encryptedBase64);
    return _encrypter().decrypt64(normalized, iv: _ivBytes());
  } catch (_) {
    return null;
  }
}

/// Mirrors React's inline normalization before POSTing to `/orders/status`:
/// URL-safe-charset repair only (spaces/`-`/`_` back to standard base64
/// chars) — deliberately NOT the same as `_normalizeBase64` used by
/// [decryptPayload], which also restores `=` padding. The backend expects
/// this raw encrypted token verbatim as `encryptedData` and decrypts it
/// itself; do not decrypt it client-side before sending it.
String normalizeEncryptedToken(String raw) {
  return raw.trim().replaceAll(' ', '+').replaceAll('-', '+').replaceAll('_', '/');
}

/// Result of decrypting a payment gateway's `txnid`/`txnId` callback token.
class DecryptedOrderRef {
  final String orderNumber;
  final String? clientId;
  const DecryptedOrderRef({required this.orderNumber, this.clientId});
}

/// Mirrors the exact "decrypt transaction ID and extract order number +
/// clientId" logic in PaymentResult.tsx:
///   1. trim + turn any literal spaces back into '+' (URL decoding artifact)
///   2. AES-decrypt
///   3. expect an "orderNumber|clientId" payload — split on '|'
///
/// This is the piece that lets the payment-result screen recover which
/// order to mark PAID / fetch coupons for, using ONLY the URL the payment
/// gateway redirected back to — it does not depend on any in-memory
/// checkout state still being alive (important if the app was relaunched
/// via the gateway's redirect/deep link rather than continuing the same
/// in-app WebView session).
DecryptedOrderRef? decryptOrderRefFromTxnId(String txnId) {
  final normalizedTxnId = txnId.trim().replaceAll(' ', '+');
  final decrypted = decryptPayload(normalizedTxnId);
  if (decrypted == null || !decrypted.contains('|')) return null;

  final parts = decrypted.split('|');
  final orderNumber = parts[0].trim();
  final clientId = parts.length > 1 ? parts[1].trim() : null;
  if (orderNumber.isEmpty) return null;

  return DecryptedOrderRef(orderNumber: orderNumber, clientId: clientId);
}
