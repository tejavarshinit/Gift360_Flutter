int supercoinItemCapCoins({
  required double itemTotal,
  required double capPercent,
  required double multiplier,
}) {
  final itemRupeeCap = itemTotal * (capPercent / 100);
  return (itemRupeeCap * multiplier).ceil();
}
