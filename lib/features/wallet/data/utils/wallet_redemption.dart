int walletItemCashbackScale4(double lineTotal, double percent) {
  final lineTotalPaise = (lineTotal * 100).round();
  final percentBasis = (percent * 100).round();
  final product = lineTotalPaise * percentBasis;
  final quotient = product ~/ 100;
  final remainder = product % 100;
  return remainder * 2 >= 100 ? quotient + 1 : quotient;
}

/// Calculates the wallet redemption cap in paise, matching React's
/// `walletCapPaise` and the backend's HALF_UP rounding.
int walletRedemptionCapPaise(
  int cashbackValueScale4,
  double redeemPercent,
  double maxRedeemAmount,
) {
  final percentOfCashbackPaise = (cashbackValueScale4 * redeemPercent / 10000)
      .round();
  final maxRedeemPaise = (maxRedeemAmount * 100).round();
  return percentOfCashbackPaise < maxRedeemPaise
      ? percentOfCashbackPaise
      : maxRedeemPaise;
}
