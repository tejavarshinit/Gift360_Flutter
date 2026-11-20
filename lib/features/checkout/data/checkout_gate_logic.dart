import 'dart:math' as math;

import 'package:gift360/features/checkout/data/models/checkout_models.dart';

const checkoutLocationReuse = Duration(minutes: 4);

bool needsEmailStep(CheckoutRequirements requirements) {
  final email = requirements.email;
  return email != null && !email.verified && (email.prompt || email.required);
}

bool needsLocationStep(CheckoutRequirements requirements) =>
    requirements.location?.ask == true;

CheckoutLocation? freshCheckoutLocation({
  required CheckoutLocation? location,
  required int maxAgeSeconds,
  required int nowEpochMs,
}) {
  if (location == null) return null;
  final limitMs = math.min(
    checkoutLocationReuse.inMilliseconds,
    maxAgeSeconds * 1000 - 30000,
  );
  if (limitMs <= 0) return null;
  final ageMs = nowEpochMs - location.capturedAt;
  return ageMs >= 0 && ageMs < limitMs ? location : null;
}

String invalidEmailMessage(String? reason) {
  switch (reason) {
    case 'DISPOSABLE':
      return "Temporary email addresses can't receive invoices and vouchers. Please use your regular email.";
    case 'TOO_MANY_ACCOUNTS':
      return 'This email is already used by other Gift360 accounts. Please use a different email.';
    case 'NO_MAIL_DOMAIN':
      return "We can't deliver email to this address. Please check it for typos.";
    case 'EMPTY':
      return 'Your account has no email address yet.';
    default:
      return "This email address doesn't look right.";
  }
}

String? emailSendStatusMessage(String status, {int? retryAfterSeconds}) {
  switch (status) {
    case 'SENT':
      return null;
    case 'RATE_LIMITED':
      return 'Too many codes requested. Try again in an hour.';
    case 'LOCKED':
      final minutes = ((retryAfterSeconds ?? 1800) / 60).ceil();
      final unit = minutes == 1 ? 'minute' : 'minutes';
      return 'Too many wrong codes. Try again in $minutes $unit.';
    case 'SEND_FAILED':
      return "We couldn't send the code just now. Please try again.";
    case 'INVALID_EMAIL':
    case 'IN_USE':
      return "This email can't be verified. Please update it in your Profile.";
    case 'NO_EMAIL':
      return 'Your account has no email address. Please update it in your Profile.';
    default:
      // ALREADY_VERIFIED and DISABLED are handled as successful continuation.
      return null;
  }
}

String? emailConfirmStatusMessage(
  String status, {
  int? attemptsLeft,
  int? retryAfterSeconds,
}) {
  switch (status) {
    case 'WRONG_CODE':
      final attempts = attemptsLeft ?? 0;
      return 'That code is not right. $attempts ${attempts == 1 ? 'try' : 'tries'} left.';
    case 'EXPIRED':
      return 'That code has expired. Send a new one.';
    case 'NO_CODE':
      return 'Please send a code first.';
    case 'LOCKED':
      final minutes = ((retryAfterSeconds ?? 1800) / 60).ceil();
      final unit = minutes == 1 ? 'minute' : 'minutes';
      return 'Too many wrong codes. Try again in $minutes $unit.';
    case 'NO_EMAIL':
      return 'Your account has no email address. Please update it in your Profile.';
    default:
      // VERIFIED, ALREADY_VERIFIED and DISABLED are handled as continuation.
      return null;
  }
}
