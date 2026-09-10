import 'package:gift360/config/app_config.dart';

class WalletBalance {
  final String? clientId;
  final double? totalBalance;
  final double? balance;
  final double? cardBalance;
  final double? bonusBalance;
  final double? offerBalance;
  final double? cashBalance;
  final double? voucherCashbackBalance;
  final double cashbackRedeemPercent;
  final double maxRedeemAmount;

  const WalletBalance({
    this.clientId,
    this.totalBalance,
    this.balance,
    this.cardBalance,
    this.bonusBalance,
    this.offerBalance,
    this.cashBalance,
    this.voucherCashbackBalance,
    this.cashbackRedeemPercent = 50,
    this.maxRedeemAmount = 100,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return WalletBalance(
      clientId: json['clientId'] as String?,
      totalBalance: parseAmount(json['totalBalance']),
      balance: parseAmount(json['balance']),
      cardBalance: parseAmount(json['cardBalance']),
      bonusBalance: parseAmount(json['bonusBalance']),
      offerBalance: parseAmount(json['offerBalance']),
      cashBalance: parseAmount(json['cashBalance']),
      voucherCashbackBalance: parseAmount(json['voucherCashbackBalance']),
      cashbackRedeemPercent: parseAmount(
        json['cashbackRedeemPercent'],
        AppConfig.cashbackRedeemPercent,
      ),
      maxRedeemAmount: parseAmount(
        json['maxRedeemAmount'],
        AppConfig.maxRedeemAmount,
      ),
    );
  }
}
