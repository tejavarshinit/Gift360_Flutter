import 'dart:convert';
import 'package:crypto/crypto.dart';

class AppUtils {
  AppUtils._();

  static String formatCurrency(double amount) {
    return '₹ ${amount.toStringAsFixed(2)}';
  }

  static String formatCurrencyShort(double amount) {
    if (amount >= 100000) {
      return '₹ ${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹ ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹ ${amount.toStringAsFixed(0)}';
  }

  static String maskString(String text, {int visibleChars = 4}) {
    if (text.length <= visibleChars) return text;
    final masked = '*' * (text.length - visibleChars);
    return '${text.substring(0, visibleChars)}$masked';
  }

  static String maskMobile(String mobile) {
    if (mobile.length != 10) return mobile;
    return '${mobile.substring(0, 2)}******${mobile.substring(8)}';
  }

  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '***@$domain';
    return '${name.substring(0, 2)}***@$domain';
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool isValidMobile(String mobile) {
    return RegExp(r'^[0-9]{10}$').hasMatch(mobile);
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  static bool isValidOtp(String otp) {
    return RegExp(r'^[0-9]{4,6}$').hasMatch(otp);
  }

  static String decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '';
      final payload = parts[1];
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64Url.decode(normalized));
      return decoded;
    } catch (_) {
      return '';
    }
  }

  static Map<String, dynamic>? parseJwt(String token) {
    try {
      final payloadStr = decodeJwtPayload(token);
      if (payloadStr.isEmpty) return null;
      return jsonDecode(payloadStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
