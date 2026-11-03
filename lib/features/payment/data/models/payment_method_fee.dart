import 'dart:math' as math;

/// Cash payment method + the platform fee it carries (UPI/DC/CC percent,
/// NB flat). Rates live in the backend `payment_method_fee` table and are
/// served by GET /v1/payment-method-fees. Ported from React
/// `PaymentMethodFee` / `computeMethodFee` in `hooks/usePaymentMethodFees.ts`.
enum PaymentFeeType { percent, flat }

class PaymentMethodFee {
  final String code;
  final String label;
  final PaymentFeeType feeType;
  final double feeValue;

  const PaymentMethodFee({
    required this.code,
    required this.label,
    required this.feeType,
    required this.feeValue,
  });

  bool get isFlat => feeType == PaymentFeeType.flat;

  factory PaymentMethodFee.fromJson(Map<String, dynamic> json) {
    final rawType = (json['feeType'] ?? '').toString().toUpperCase();
    return PaymentMethodFee(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? json['code'] ?? '').toString(),
      feeType: rawType == 'FLAT' ? PaymentFeeType.flat : PaymentFeeType.percent,
      feeValue: (json['feeValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Platform fee for a cash amount: percent (or flat) of the cash payable,
/// rounded half-up to the paisa -- same rule as the backend, which is the
/// authority and recomputes it. Zero when there is no cash to pay.
double computeMethodFee(PaymentMethodFee? method, double cashAmount) {
  if (method == null || !(cashAmount > 0)) return 0;
  final cash = (cashAmount * 100).round() / 100;
  final int paise;
  if (method.isFlat) {
    paise = (method.feeValue * 100).round();
  } else {
    paise = ((cash * 100 * method.feeValue) / 100 + 0.5 + 1e-9).floor();
  }
  return paise / 100;
}

/// Convenience: pick the active method for a code, falling back to the first
/// one offered (matches React `paymentMethods.find(...) ?? paymentMethods[0]`).
PaymentMethodFee? activePaymentMethod(
  List<PaymentMethodFee> methods,
  String? code,
) {
  if (methods.isEmpty) return null;
  for (final m in methods) {
    if (m.code == code) return m;
  }
  return methods.first;
}

const List<String> _methodSubtext = [
  'GPay, PhonePe, Paytm, BHIM',
  'Visa, Mastercard, RuPay',
  'Visa, Mastercard, Amex',
  'All major banks',
];

String paymentMethodSubtext(String code) {
  switch (code) {
    case 'UPI':
      return _methodSubtext[0];
    case 'DC':
      return _methodSubtext[1];
    case 'CC':
      return _methodSubtext[2];
    case 'NB':
      return _methodSubtext[3];
    default:
      return '';
  }
}

String paymentMethodFeeLabel(PaymentMethodFee method) {
  final formatted = _trimNumber(method.feeValue);
  return method.isFlat ? '\u20b9$formatted flat fee' : '$formatted% fee';
}

String _trimNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}

/// Lowest fee across the offered methods (for the "Lowest fee" badge).
double lowestMethodFee(List<PaymentMethodFee> methods, double cashAmount) {
  if (methods.isEmpty) return 0;
  return methods
      .map((m) => computeMethodFee(m, cashAmount))
      .reduce((a, b) => math.min(a, b));
}

// ---------------------------------------------------------------------------
// UPI settles through the Juspay UPI-intent flow; the Easebuzz hosted checkout
// must never offer UPI, so its initiation payload carries every OTHER mode
// (NB / Debit / Credit). Ported from React `lib/paymentModes.ts`.
// ---------------------------------------------------------------------------

const String upiMethodCode = 'UPI';

bool isUpiPaymentMethod(String? code) =>
    (code ?? '').trim().toUpperCase() == upiMethodCode;

/// Modes for the Easebuzz payload: everything except UPI, order preserved,
/// de-duped.
List<String> easebuzzPaymentModes(List<PaymentMethodFee> methods) {
  final seen = <String>{};
  final modes = <String>[];
  for (final method in methods) {
    final code = method.code.trim();
    if (code.isEmpty || isUpiPaymentMethod(code) || seen.contains(code)) continue;
    seen.add(code);
    modes.add(code);
  }
  return modes;
}
