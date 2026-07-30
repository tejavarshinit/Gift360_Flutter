class WalletBalance {
  final String? clientId;
  final double? totalBalance;
  final double? balance;
  final double? cardBalance;
  final double? bonusBalance;
  final double? offerBalance;
  final double? cashBalance;
  final double? voucherCashbackBalance;

  const WalletBalance({
    this.clientId,
    this.totalBalance,
    this.balance,
    this.cardBalance,
    this.bonusBalance,
    this.offerBalance,
    this.cashBalance,
    this.voucherCashbackBalance,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      clientId: json['clientId'] as String?,
      totalBalance: (json['totalBalance'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      cardBalance: (json['cardBalance'] ?? 0).toDouble(),
      bonusBalance: (json['bonusBalance'] ?? 0).toDouble(),
      offerBalance: (json['offerBalance'] ?? 0).toDouble(),
      cashBalance: (json['cashBalance'] ?? 0).toDouble(),
      voucherCashbackBalance: (json['voucherCashbackBalance'] ?? 0).toDouble(),
    );
  }
}
