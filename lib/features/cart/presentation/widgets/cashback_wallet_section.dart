import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/config/app_config.dart';

class CashbackWalletSection extends ConsumerWidget {
  final double cashbackPercent;
  final double cashbackAmount;
  final double walletBalance;
  final double maxWalletUsage;
  final double walletDeduction;
  final bool useWalletBalance;
  final VoidCallback onToggleWallet;

  const CashbackWalletSection({
    super.key,
    required this.cashbackPercent,
    required this.cashbackAmount,
    required this.walletBalance,
    required this.maxWalletUsage,
    required this.walletDeduction,
    required this.useWalletBalance,
    required this.onToggleWallet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Earn Cashback Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD1FAE5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Earn Cashback',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (cashbackPercent > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${cashbackPercent.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Earn ₹${cashbackAmount.toStringAsFixed(2)} in cashback after purchase',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Redeem Wallet Points Card
        GestureDetector(
          onTap: walletBalance > 0 ? onToggleWallet : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: useWalletBalance
                  ? const Color(0xFF9747FF).withValues(alpha: 0.08)
                  : const Color(0xFF9747FF).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: useWalletBalance
                    ? const Color(0xFF9747FF).withValues(alpha: 0.3)
                    : const Color(0xFF9747FF).withValues(alpha: 0.2),
              ),
              // Left accent border when active
            ),
            child: Row(
              children: [
                // Radio indicator
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: useWalletBalance ? const Color(0xFF9747FF) : Colors.grey[400]!,
                      width: 2,
                    ),
                    color: useWalletBalance ? const Color(0xFF9747FF) : Colors.transparent,
                  ),
                  child: useWalletBalance
                      ? const Center(
                          child: CircleAvatar(
                            radius: 4,
                            backgroundColor: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Icon(Icons.account_balance_wallet, size: 18, color: const Color(0xFF9747FF).withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Redeem Wallet Points',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Available: ₹${walletBalance.toStringAsFixed(2)} • Max: ₹${maxWalletUsage.toStringAsFixed(2)} (${AppConfig.cashbackRedeemPercent.round()}% of cart)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      if (walletBalance <= 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'No wallet balance available',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400], fontStyle: FontStyle.italic),
                          ),
                        ),
                      if (useWalletBalance && walletDeduction > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '-₹${walletDeduction.toStringAsFixed(2)} will be deducted',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF10B981)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
