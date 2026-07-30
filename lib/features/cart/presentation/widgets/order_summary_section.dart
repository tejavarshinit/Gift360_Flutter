import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_checkout_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/data/models/payment.dart';

class OrderSummarySection extends ConsumerWidget {
  final VoidCallback onSuperCoinTap;

  const OrderSummarySection({super.key, required this.onSuperCoinTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(cartCheckoutProvider);
    final breakdown = ref.watch(paymentBreakdownProvider);
    final brandTotals = ref.watch(brandTotalsProvider);
    final walletAsync = ref.watch(walletBalanceProvider);
    final superCoinState = ref.watch(supercoinProvider);
    final paymentState = ref.watch(paymentProvider);

    final walletBalance = (walletAsync.value?.totalBalance ?? 0).toDouble();

    String countdownDisplay(int seconds) {
      final mins = (seconds ~/ 60).toString().padLeft(2, '0');
      final secs = (seconds % 60).toString().padLeft(2, '0');
      return '$mins:$secs';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
            blurRadius: 45,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Order Summary',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 16),

          // Brand line items
          ...brandTotals.entries.map((entry) {
            final data = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.brand,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (data.discount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${data.discount.toStringAsFixed(0)}% Cashback',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${data.quantity} × ₹${data.price.toStringAsFixed(2)} = ₹${data.total.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // Divider
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 16),

          // ── Rewards Toggle (Section 4G) ──
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                // Cashback & Wallet
                Expanded(
                  child: GestureDetector(
                    onTap: () => _requestSwitchToCashback(context, ref, checkout),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: checkout.rewardMode == RewardMode.cashbackWallet
                            ? const Color(0xFFD1FAE5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: checkout.rewardMode == RewardMode.cashbackWallet
                            ? [BoxShadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.05))]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: checkout.rewardMode == RewardMode.cashbackWallet
                                ? const Color(0xFF2D2D2D)
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cashback & Wallet',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: checkout.rewardMode == RewardMode.cashbackWallet
                                  ? const Color(0xFF2D2D2D)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // SuperCoins
                Expanded(
                  child: GestureDetector(
                    onTap: () => ref.read(cartCheckoutProvider.notifier).setRewardMode(RewardMode.superCoins),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: checkout.rewardMode == RewardMode.superCoins
                            ? const Color(0xFFD1FAE5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: checkout.rewardMode == RewardMode.superCoins
                            ? [BoxShadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.05))]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/SuperCOin-removebg-preview.png',
                            width: 16,
                            height: 16,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SuperCoins',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: checkout.rewardMode == RewardMode.superCoins
                                  ? const Color(0xFF2D2D2D)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cashback & Wallet content
          if (checkout.rewardMode == RewardMode.cashbackWallet) ...[
            // Earn Cashback card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(alpha: 0.06),
                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Earn Cashback',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                      if (breakdown.cashbackPercent > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${breakdown.cashbackPercent.toStringAsFixed(0)}%)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Earn ₹${breakdown.cashbackAmount.toStringAsFixed(2)} in cashback after purchase',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Wallet redemption card
            GestureDetector(
              onTap: walletBalance > 0
                  ? () => ref.read(cartCheckoutProvider.notifier).toggleWallet()
                  : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: checkout.useWalletBalance
                      ? const Color(0xFF9747FF).withValues(alpha: 0.08)
                      : const Color(0xFF9747FF).withValues(alpha: 0.05),
                  border: Border.all(
                    color: const Color(0xFF9747FF).withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
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
                          color: checkout.useWalletBalance
                              ? const Color(0xFF9747FF)
                              : const Color(0xFF9CA3AF).withValues(alpha: 0.4),
                          width: 2,
                        ),
                        color: checkout.useWalletBalance ? const Color(0xFF9747FF) : Colors.transparent,
                      ),
                      child: checkout.useWalletBalance
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF9747FF)),
                              const SizedBox(width: 8),
                              Text(
                                'Redeem Wallet Points',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF2D2D2D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Available: ₹${walletBalance.toStringAsFixed(2)} • Max: ₹${breakdown.walletDeduction.toStringAsFixed(2)} (50% of cart)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          if (walletBalance <= 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'No wallet balance available',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (checkout.useWalletBalance && breakdown.walletDeduction > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '-₹${breakdown.walletDeduction.toStringAsFixed(2)} will be deducted',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF10B981),
                              ),
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

          // SuperCoins content
          if (checkout.rewardMode == RewardMode.superCoins) ...[
            if (!checkout.superCoinAuthorized) ...[
              if (superCoinState.isEnrolled) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/SuperCOin-removebg-preview.png',
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SuperCoin balance: ${superCoinState.balance.toStringAsFixed(2)} coins',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/SuperCOin-removebg-preview.png',
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'You can use ${breakdown.maxSuperCoinRedeemable.toStringAsFixed(2)} coins on this order',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2D2D2D)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: superCoinState.balance <= 0 ? null : onSuperCoinTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Apply SuperCoins', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1FAE5)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/SuperCOin-removebg-preview.png',
                          width: 16,
                          height: 16,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'SuperCoins active',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await ref.read(cartCheckoutProvider.notifier).cancelSuperCoinHold();
                            ref.read(cartCheckoutProvider.notifier).setRewardMode(RewardMode.cashbackWallet);
                          },
                          child: Text(
                            'Remove',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                    if (!checkout.superCoinCountdownExpired && checkout.superCoinCountdownSeconds > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            'Use your SuperCoins within ${countdownDisplay(checkout.superCoinCountdownSeconds)}',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFF59E0B)),
                          ),
                        ],
                      ),
                    ],
                    if (checkout.superCoinCountdownExpired)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'SuperCoin hold expired. Please apply again.',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFEF4444)),
                        ),
                      ),
                    if (breakdown.superCoinDeduction > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Saving ₹${breakdown.superCoinDeduction.toStringAsFixed(2)} on this order',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF374151)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 16),

          // Subtotal
          _summaryRow('Subtotal', '₹${breakdown.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),

          // Wallet deduction
          if (checkout.useWalletBalance && breakdown.walletDeduction > 0)
            _summaryRow('Wallet Deduction', '-₹${breakdown.walletDeduction.toStringAsFixed(2)}', color: const Color(0xFF10B981), icon: Icons.account_balance_wallet),

          // Coupon discount
          if (breakdown.couponDiscount > 0)
            _summaryRow('Coupon Discount', '-₹${breakdown.couponDiscount.toStringAsFixed(2)}', color: const Color(0xFF9747FF), icon: Icons.local_offer),

          // SuperCoin deduction
          if (breakdown.superCoinDeduction > 0)
            _superCoinDiscountRow('SuperCoins discount', breakdown.superCoinDeduction),

          const SizedBox(height: 8),
          // Processing fee
          _summaryRow('Processing Fee', '₹${breakdown.processingFee.toStringAsFixed(2)}'),
          const SizedBox(height: 16),

          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 16),

          // Total to Pay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total to Pay',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${breakdown.finalPayable.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9747FF),
                    ),
                  ),
                  // SuperCoin earn preview — right under value
                  if (checkout.rewardMode == RewardMode.superCoins && breakdown.estimatedEarn > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/SuperCOin-removebg-preview.png',
                          width: 12,
                          height: 12,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Earn ${breakdown.estimatedEarn.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pay button
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9747FF), Color(0xFFB888FF)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: paymentState.isLoading ? null : () => _handlePay(context, ref),
                child: Center(
                  child: paymentState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Pay with SabbPe',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Loading status
          if (paymentState.isLoading) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getLoadingMessage(paymentState),
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.amber[100]),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Continue Shopping
          Container(
            width: double.infinity,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD7BDFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go('/brands'),
                child: Center(
                  child: Text(
                    'Continue Shopping',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _superCoinDiscountRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF10B981),
            ),
          ),
          Row(
            children: [
              Text(
                '-',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF10B981),
                ),
              ),
              Image.asset(
                'assets/images/SuperCOin-removebg-preview.png',
                width: 14,
                height: 14,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 2),
              Text(
                amount.toStringAsFixed(2),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, IconData? icon, String? imageAsset}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (imageAsset != null) ...[
                Image.asset(imageAsset, width: 16, height: 16, fit: BoxFit.contain),
                const SizedBox(width: 4),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: const Color(0xFF6B7280)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: color ?? const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? const Color(0xFF2D2D2D),
            ),
          ),
        ],
      ),
    );
  }

  String _getLoadingMessage(dynamic paymentState) {
    if (paymentState.orderCreated == false) return 'Creating order...';
    if (paymentState.orderValidated == false) return 'Validating order...';
    if (paymentState.tokenResponse == null) return 'Generating secure token...';
    return 'Processing...';
  }

  void _requestSwitchToCashback(BuildContext context, WidgetRef ref, CartCheckoutState checkout) {
    if (!checkout.superCoinAuthorized) {
      ref.read(cartCheckoutProvider.notifier).setRewardMode(RewardMode.cashbackWallet);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove your SuperCoins from this purchase?', style: GoogleFonts.poppins()),
        content: Text('Your reserved SuperCoins will not be used for this payment.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(cartCheckoutProvider.notifier).cancelSuperCoinHold();
              ref.read(cartCheckoutProvider.notifier).setRewardMode(RewardMode.cashbackWallet);
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: Text('Remove', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePay(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue')),
      );
      context.push('/login');
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart == null || cart.items.isEmpty) return;

    final checkoutNotifier = ref.read(cartCheckoutProvider.notifier);
    final paymentNotifier = ref.read(paymentProvider.notifier);
    final breakdown = ref.read(paymentBreakdownProvider);
    final checkout = ref.read(cartCheckoutProvider);

    checkoutNotifier.setProcessing(true);

    try {
      final orderItems = cart.items.map((item) => {
        'brandId': item.brandId,
        'quantity': item.quantity,
        'unitValue': item.unitValue,
        'lineTotal': item.lineTotal,
        'meta': jsonEncode({'brand_id': item.brandId, 'brand_name': item.brandName}),
      }).toList();

      final orderNumber = await paymentNotifier.createOrder(
        clientId: user.clientId,
        items: List<Map<String, dynamic>>.from(orderItems),
        totalAmount: cart.totalAmount,
        walletUsed: checkout.useWalletBalance,
        walletAmount: breakdown.walletDeduction,
      );

      if (orderNumber == null) {
        checkoutNotifier.setProcessing(false);
        checkoutNotifier.setPaymentError('Failed to create order');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create order')));
        }
        return;
      }

      final validated = await paymentNotifier.validateOrder(
        cartTotal: cart.totalAmount,
        walletAmount: breakdown.walletDeduction,
        walletUsed: checkout.useWalletBalance,
      );

      if (!validated) {
        checkoutNotifier.setProcessing(false);
        if (context.mounted) {
          final msg = ref.read(paymentProvider).error ?? 'Order validation failed';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }

      final tokenGenerated = await paymentNotifier.generateToken();
      if (!tokenGenerated) {
        checkoutNotifier.setProcessing(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate payment token')),
          );
        }
        return;
      }

      final encryptedOrderRef = encryptOrderRef(ref.read(paymentProvider).orderNumber ?? '', user.clientId);
      final productInfo = cart.items.map((i) => i.brandName).join(', ');

      final initiated = await paymentNotifier.initiatePayment(
        amount: breakdown.finalPayable,
        productInfo: productInfo.isNotEmpty ? productInfo : 'Gift Voucher Purchase',
        frontendUrl: AppConfig.sabbpeFrontendUrl,
        customer: CustomerInfo(
          firstname: AppConfig.paymentCustFirstName,
          email: AppConfig.paymentCustEmail,
          phone: AppConfig.paymentCustMobile,
        ),
        encryptedOrderRef: encryptedOrderRef,
        clientId: user.clientId,
      );

      if (!initiated) {
        checkoutNotifier.setProcessing(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initiate payment')),
          );
        }
        return;
      }

      final paymentUrl = ref.read(paymentProvider).initiateResponse?.paymentUrl;
      if (paymentUrl != null && context.mounted) {
        ref.read(cartProvider.notifier).clearCart();
        checkoutNotifier.setProcessing(false);
        context.push('/payment-webview', extra: {
          'paymentUrl': paymentUrl,
          'orderNumber': ref.read(paymentProvider).orderNumber,
        });
      }
    } catch (e) {
      checkoutNotifier.setProcessing(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }
  }
}
