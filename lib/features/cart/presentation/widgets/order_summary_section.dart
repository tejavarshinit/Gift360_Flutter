import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_checkout_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_earn_provider.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/home/presentation/providers/home_providers.dart';
import 'package:gift360/features/payment/data/models/payment_method_fee.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/presentation/widgets/pay_using_sheet.dart';

class OrderSummarySection extends ConsumerWidget {
  final VoidCallback onSuperCoinTap;
  final VoidCallback onPaymentStart;
  final VoidCallback onPaymentComplete;

  const OrderSummarySection({
    super.key,
    required this.onSuperCoinTap,
    required this.onPaymentStart,
    required this.onPaymentComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(cartCheckoutProvider);
    final breakdown = ref.watch(paymentBreakdownProvider);
    final brandTotals = ref.watch(brandTotalsProvider);
    final walletAsync = ref.watch(walletBalanceProvider);
    final superCoinState = ref.watch(supercoinProvider);
    final superCoinConfig = ref.watch(superCoinConfigProvider).valueOrNull;
    final paymentState = ref.watch(paymentProvider);
    final cart = ref.watch(cartProvider);

    // Backend-computed SuperCoin earn estimate (React useSuperCoinEarnEstimate):
    // computed on the cash actually paid for the vouchers (excludes the fee and
    // previews the slider's SuperCoins, like React's `displayCash`).
    final earnKey = superCoinEarnKey(
      (cart?.items ?? const [])
          .map((i) => MapEntry(i.brandId, i.lineTotal))
          .toList(),
      breakdown.displayCash,
    );
    final estimatedEarn = checkout.rewardMode == RewardMode.superCoins
        ? (ref.watch(superCoinEarnEstimateProvider(earnKey)).valueOrNull ?? 0.0)
        : 0.0;

    // If every cart item is SuperCoin-excluded, hide the SuperCoins tab.
    final brandShares =
        ref.watch(superCoinBrandSharesProvider).valueOrNull ??
        const <String, double>{};
    final allSuperCoinExcluded =
        cart != null &&
        cart.items.isNotEmpty &&
        cart.items.every(
          (i) => isSuperCoinExcludedWithShares(
            brandShares,
            brandId: i.brandId,
            brandName: i.brandName,
          ),
        );

    final walletBalance = (walletAsync.value?.totalBalance ?? 0).toDouble();
    final cashbackRedeemPercent =
        walletAsync.value?.cashbackRedeemPercent ?? 50.0;

    String countdownDisplay(int seconds) {
      final mins = (seconds ~/ 60).toString().padLeft(2, '0');
      final secs = (seconds % 60).toString().padLeft(2, '0');
      return '$mins:$secs';
    }

    // SuperCoin slider bounds (React Cart.tsx): 1 coin minimum, upper bound
    // = min(balance, cap). Selection defaults to the max until the user drags.
    final maxSCCoins = superCoinState.balance < breakdown.maxSuperCoinRedeemable
        ? superCoinState.balance
        : breakdown.maxSuperCoinRedeemable;
    final rawSelectedSC = checkout.selectedSuperCoinCoins;
    final selectedSC = maxSCCoins < 1
        ? 0.0
        : (rawSelectedSC < 1
              ? maxSCCoins
              : (rawSelectedSC > maxSCCoins ? maxSCCoins : rawSelectedSC));
    final scMultiplier = breakdown.effectiveSupercoinMultiplier > 0
        ? breakdown.effectiveSupercoinMultiplier
        : 1.25;
    final scCapPercent = superCoinConfig?.capPercent ?? 20;
    // Rate caption from each brand's own DB multiplier (React `scRateText`).
    final scRates = <double>{};
    for (final item in cart?.items ?? const []) {
      if (isSuperCoinExcludedWithShares(
        brandShares,
        brandId: item.brandId,
        brandName: item.brandName,
      )) {
        continue;
      }
      final m = checkout.brandSupercoinMultipliers[item.brandId];
      if (m != null && m > 0) scRates.add(m);
    }
    final scRateList = scRates.toList()..sort();
    String fmtRate(double n) =>
        n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
    final scRateText = scRateList.isEmpty
        ? ''
        : scRateList.length == 1
        ? '\u20b91 = ${fmtRate(scRateList.first)} SC'
        : '\u20b91 = ${fmtRate(scRateList.first)}\u2013${fmtRate(scRateList.last)} SC';
    // Integer snap steps (React `step={1}`), always >= 1 for Slider asserts.
    final sliderDivisions = maxSCCoins > 1.5 ? (maxSCCoins - 1).round() : 1;

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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.1),
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
                    onTap: () =>
                        _requestSwitchToCashback(context, ref, checkout),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: checkout.rewardMode == RewardMode.cashbackWallet
                            ? const Color(0xFFD1FAE5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow:
                            checkout.rewardMode == RewardMode.cashbackWallet
                            ? [
                                BoxShadow(
                                  blurRadius: 4,
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color:
                                checkout.rewardMode == RewardMode.cashbackWallet
                                ? const Color(0xFF2D2D2D)
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cashback & Wallet',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  checkout.rewardMode ==
                                      RewardMode.cashbackWallet
                                  ? const Color(0xFF2D2D2D)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // SuperCoins (hidden when all items are SuperCoin-excluded)
                if (!allSuperCoinExcluded)
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        ref
                            .read(cartCheckoutProvider.notifier)
                            .setRewardMode(RewardMode.superCoins);
                        await ref.read(supercoinProvider.notifier).refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: checkout.rewardMode == RewardMode.superCoins
                              ? const Color(0xFFD1FAE5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow:
                              checkout.rewardMode == RewardMode.superCoins
                              ? [
                                  BoxShadow(
                                    blurRadius: 4,
                                    color: Colors.black.withValues(alpha: 0.05),
                                  ),
                                ]
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
                                color:
                                    checkout.rewardMode == RewardMode.superCoins
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
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.25),
                ),
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
                        color: checkout.useWalletBalance
                            ? const Color(0xFF9747FF)
                            : Colors.transparent,
                      ),
                      child: checkout.useWalletBalance
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                size: 16,
                                color: Color(0xFF9747FF),
                              ),
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
                            'Available: ₹${walletBalance.toStringAsFixed(2)} • Max: ₹${breakdown.maxWalletUsage.toStringAsFixed(2)} (${cashbackRedeemPercent.round()}% of cart)',
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
                          if (checkout.useWalletBalance &&
                              breakdown.walletDeduction > 0) ...[
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
              // Keep the React SuperCoinStatusCard visible while the account
              // lookup is settling so the selected reward flow is not blank.
              if (superCoinState.isEnrolled || superCoinState.balance >= 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9747FF).withValues(alpha: 0.04),
                    border: Border.all(
                      color: const Color(0xFF9747FF).withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/SuperCOin-removebg-preview.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: const Color(0xFF2D2D2D),
                                ),
                                children: [
                                  const TextSpan(text: 'Save more with '),
                                  TextSpan(
                                    text: 'SuperCoins',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF5B3FFF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Powered by Flipkart',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            if (superCoinState.isSearching ||
                                superCoinState.isBalanceLoading)
                              Text(
                                'Loading SuperCoin balance...',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            if (superCoinState.error != null)
                              Text(
                                'Unable to load SuperCoins. Please try again.',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // "Coins to use" slider (mirrors React Cart.tsx coin slider:
                // header row, range input, Save/Max footer).
                if (maxSCCoins >= 1)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9747FF).withValues(alpha: 0.06),
                      border: Border.all(
                        color: const Color(0xFF9747FF).withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                Text(
                                  'Coins to use',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${selectedSC.toStringAsFixed(0)} SC',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: selectedSC,
                          min: 1,
                          max: maxSCCoins,
                          divisions: sliderDivisions,
                          activeColor: const Color(0xFF9747FF),
                          inactiveColor: const Color(
                            0xFF9747FF,
                          ).withValues(alpha: 0.2),
                          onChanged: (v) => ref
                              .read(cartCheckoutProvider.notifier)
                              .setSelectedSuperCoinCoins(v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Save ₹${(selectedSC / scMultiplier).toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                            Text(
                              '${scRateText.isNotEmpty ? '$scRateText \u00b7 ' : ''}up to $scCapPercent% of voucher value',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
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
                  onPressed:
                      superCoinState.balance <= 0 ||
                          maxSCCoins < 1 ||
                          selectedSC < 1
                      ? null
                      : onSuperCoinTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply SuperCoins',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
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
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await ref
                                .read(cartCheckoutProvider.notifier)
                                .cancelSuperCoinHold();
                            ref
                                .read(cartCheckoutProvider.notifier)
                                .setRewardMode(RewardMode.cashbackWallet);
                          },
                          child: Text(
                            'Remove',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!checkout.superCoinCountdownExpired &&
                        checkout.superCoinCountdownSeconds > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Use your SuperCoins within ${countdownDisplay(checkout.superCoinCountdownSeconds)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (checkout.superCoinCountdownExpired)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'SuperCoin hold expired. Please apply again.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    if (breakdown.superCoinDeduction > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Saving ₹${breakdown.superCoinDeduction.toStringAsFixed(2)} on this order',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF374151),
                        ),
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
            _summaryRow(
              'Wallet Deduction',
              '-₹${breakdown.walletDeduction.toStringAsFixed(2)}',
              color: const Color(0xFF10B981),
              icon: Icons.account_balance_wallet,
            ),

          // Coupon discount
          if (breakdown.couponDiscount > 0)
            _summaryRow(
              'Coupon Discount',
              '-₹${breakdown.couponDiscount.toStringAsFixed(2)}',
              color: const Color(0xFF9747FF),
              icon: Icons.local_offer,
            ),

          // SuperCoin deduction
          if (breakdown.superCoinDeduction > 0)
            _superCoinDiscountRow(
              'SuperCoins discount',
              breakdown.superCoinDeduction,
            ),

          const SizedBox(height: 8),
          // Platform fee
          _summaryRow(
            'Platform Fee${breakdown.paymentMethodLabel != null ? ' \u00b7 ${breakdown.paymentMethodLabel}' : ''}',
            '₹${breakdown.processingFee.toStringAsFixed(2)}',
          ),
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
                  if (checkout.rewardMode == RewardMode.superCoins &&
                      estimatedEarn > 0) ...[
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
                          'Earn ${estimatedEarn.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pay button: opens the pay-confirm step where the cash payment
          // method (UPI/DC/CC/NB) is chosen, exactly like React's payOpen
          // panel with PaymentMethodSelector.
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
                onTap: paymentState.isLoading
                    ? null
                    : () => _openPayConfirm(context, ref, estimatedEarn),
                child: Center(
                  child: paymentState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Pay \u20b9${breakdown.finalPayable.toStringAsFixed(2)}',
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
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.amber[100],
                ),
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

  Widget _summaryRow(
    String label,
    String value, {
    Color? color,
    IconData? icon,
    String? imageAsset,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (imageAsset != null) ...[
                Image.asset(
                  imageAsset,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
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
    if (paymentState.paymentInitiated == false) return 'Initiating payment...';
    return 'Processing...';
  }

  void _requestSwitchToCashback(
    BuildContext context,
    WidgetRef ref,
    CartCheckoutState checkout,
  ) {
    if (!checkout.superCoinAuthorized) {
      ref
          .read(cartCheckoutProvider.notifier)
          .setRewardMode(RewardMode.cashbackWallet);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove your SuperCoins from this purchase?',
          style: GoogleFonts.poppins(),
        ),
        content: Text(
          'Your reserved SuperCoins will not be used for this payment.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(cartCheckoutProvider.notifier)
                  .cancelSuperCoinHold();
              ref
                  .read(cartCheckoutProvider.notifier)
                  .setRewardMode(RewardMode.cashbackWallet);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text('Remove', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  /// Pay-confirm step: lets the user pick the cash payment method (UPI/DC/
  /// CC/NB) only when they press Pay, then runs the normal pay flow —
  /// React Cart's pay sheet: "YOU PAY" + earn text + a single PayUsingField
  /// control. Tapping it creates the order and opens the "Pay using" chooser
  /// (UPI apps/QR -> Juspay, cards/netbanking -> Easebuzz).
  void _openPayConfirm(
    BuildContext context,
    WidgetRef ref,
    double estimatedEarn,
  ) {
    final breakdownNow = ref.read(paymentBreakdownProvider);
    final methodsNow =
        ref.read(paymentMethodFeesProvider).valueOrNull ??
        const <PaymentMethodFee>[];
    final active = activePaymentMethod(
      methodsNow,
      ref.read(cartCheckoutProvider).selectedPaymentMethod,
    );
    final processing = ref.read(paymentProvider).isLoading;
    final inSCMode =
        ref.read(cartCheckoutProvider).rewardMode == RewardMode.superCoins;
    final earnText = inSCMode
        ? 'Earn ${estimatedEarn.toStringAsFixed(2)} SuperCoins'
        : 'Earn ${breakdownNow.cashbackAmount.toStringAsFixed(2)} cashback points'
              '${breakdownNow.cashbackPercent > 0 ? ' (${breakdownNow.cashbackPercent.toStringAsFixed(0)}%)' : ''}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayConfirmSheet(
        breakdown: breakdownNow,
        methods: methodsNow,
        methodLabel: active?.label ?? 'UPI',
        methodSubtext: payMethodSubtext(active?.code),
        earnText: earnText,
        processing: processing,
        onConfirm: () {
          Navigator.of(context).pop();
          _handlePay(context, ref);
        },
      ),
    );
  }

  String payMethodSubtext(String? code) {
    switch ((code ?? '').trim().toUpperCase()) {
      case 'UPI':
        return 'Google Pay, PhonePe, Paytm, CRED, BHIM';
      case 'DC':
        return 'Visa, Mastercard, RuPay';
      case 'CC':
        return 'Visa, Mastercard, Amex';
      case 'NB':
        return 'All major banks';
      default:
        return 'Choose how you want to pay';
    }
  }

  Future<void> _handlePay(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login to continue')));
      context.push('/login');
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart == null || cart.items.isEmpty) return;

    final checkoutNotifier = ref.read(cartCheckoutProvider.notifier);
    final paymentNotifier = ref.read(paymentProvider.notifier);
    final breakdown = ref.read(paymentBreakdownProvider);
    final checkout = ref.read(cartCheckoutProvider);

    final superCoinIdentity = _buildSuperCoinIdentity(user);

    // Show the PaymentFlowSheet loading state
    onPaymentStart();
    checkoutNotifier.setProcessing(true);

    try {
      final brandApi = ref.read(brandsApiProvider);
      final redeemStepsByBrand = <String, List<String>>{};
      final uniqueBrandIds = cart.items.map((item) => item.brandId).toSet();
      await Future.wait(
        uniqueBrandIds.map((id) async {
          try {
            final brand = await brandApi.getBrandById(id);
            redeemStepsByBrand[id] = (brand.howToUse ?? '')
                .split('\n')
                .map((step) => step.trim())
                .where((step) => step.isNotEmpty)
                .toList();
          } catch (_) {
            redeemStepsByBrand[id] = <String>[];
          }
        }),
      );

      final orderItems = cart.items
          .map(
            (item) => {
              'brandId': item.brandId,
              'quantity': item.quantity,
              'unitValue': item.unitValue,
              'lineTotal': item.lineTotal,
              'meta': jsonEncode({
                'brand_id': item.brandId,
                'brand_name': item.brandName,
                'image_url': item.image,
                'redeem_steps': redeemStepsByBrand[item.brandId] ?? <String>[],
              }),
            },
          )
          .toList();

      final earnCashback = checkout.rewardMode != RewardMode.superCoins;

      // Order reuse (matches React ensureOrder): reuse the existing order if the
      // cart signature is unchanged, so retries don't mint duplicate PENDING orders.
      final cartSignature = PaymentNotifier.cartSignatureFor(orderItems);

      final orderNumber = await paymentNotifier.createOrder(
        clientId: user.clientId,
        items: List<Map<String, dynamic>>.from(orderItems),
        totalAmount: cart.totalAmount,
        walletUsed: checkout.useWalletBalance,
        walletAmount: breakdown.walletDeduction,
        earnCashback: earnCashback,
        cartSignature: cartSignature,
      );

      if (orderNumber == null) {
        await _failPay(
          context,
          ref,
          'Failed to create order',
          checkoutNotifier,
          superCoinIdentity,
        );
        return;
      }

      // Persist SuperCoin hold context keyed by order number (survives redirect)
      if (checkout.superCoinAuthorized &&
          checkout.superCoinHoldContext != null) {
        await SuperCoinOtpNotifier.persistHoldContext(
          orderNumber,
          checkout.superCoinHoldContext!,
        );
        await SuperCoinOtpNotifier.persistActiveOrderNumber(orderNumber);
      }

      final validated = await paymentNotifier.validateOrder(
        cartTotal: cart.totalAmount,
        walletAmount: breakdown.walletDeduction,
        walletUsed: checkout.useWalletBalance,
      );

      if (!validated) {
        await _failPay(
          context,
          ref,
          ref.read(paymentProvider).error ?? 'Order validation failed',
          checkoutNotifier,
          superCoinIdentity,
        );
        return;
      }

      // ONE Pay: UPI goes to the Juspay intent flow; every other mode
      // (NB / Debit / Credit) keeps the Easebuzz hosted checkout with a payload
      // that carries every mode EXCEPT UPI.
      final feeMethods =
          ref.read(paymentMethodFeesProvider).valueOrNull ??
          const <PaymentMethodFee>[];

      // React Cart: always open the "Pay using" chooser (works with an empty
      // DB fee table too — fees then show "at checkout").
      checkoutNotifier.setProcessing(false);
      onPaymentComplete();
      _showPayUsing(
        context,
        ref,
        orderNumber,
        (breakdown.finalPayable - breakdown.processingFee).clamp(
          0.0,
          double.infinity,
        ),
        feeMethods,
        checkoutNotifier: checkoutNotifier,
        superCoinIdentity: superCoinIdentity,
      );
      return;
    } catch (e) {
      await _failPay(
        context,
        ref,
        'Payment error: $e',
        checkoutNotifier,
        superCoinIdentity,
      );
    }
  }

  /// Hosted checkout leg: initiate with the selected method (fee frozen
  /// server-side) and every mode EXCEPT UPI, then hand off to the webview.
  Future<void> _startHostedPayment(
    BuildContext context,
    WidgetRef ref,
    String orderNumber, {
    required CartCheckoutNotifier checkoutNotifier,
    required SuperCoinIdentity? superCoinIdentity,
  }) async {
    final paymentNotifier = ref.read(paymentProvider.notifier);
    final checkout = ref.read(cartCheckoutProvider);
    final feeMethods =
        ref.read(paymentMethodFeesProvider).valueOrNull ??
        const <PaymentMethodFee>[];
    final paymentResponse = await paymentNotifier.initiateBackendPayment(
      paymentMethod: feeMethods.isEmpty ? null : checkout.selectedPaymentMethod,
      paymentModes: feeMethods.isEmpty
          ? null
          : easebuzzPaymentModes(feeMethods),
    );
    if (paymentResponse == null) {
      await _failPay(
        context,
        ref,
        'Failed to initiate payment',
        checkoutNotifier,
        superCoinIdentity,
      );
      return;
    }
    final paymentUrl =
        paymentResponse['payment_url'] ?? paymentResponse['paymentUrl'];
    if (paymentUrl != null &&
        paymentUrl.toString().isNotEmpty &&
        context.mounted) {
      checkoutNotifier.setProcessing(false);
      onPaymentComplete();
      // Match React Cart: clear the submitted cart after payment initiation
      // succeeds and before leaving for the gateway.
      await ref.read(cartProvider.notifier).clearCart();
      context.push(
        '/payment-webview',
        extra: {
          'paymentUrl': paymentUrl.toString(),
          'orderNumber': orderNumber,
        },
      );
    } else {
      await _failPay(
        context,
        ref,
        'Failed to initiate payment',
        checkoutNotifier,
        superCoinIdentity,
      );
    }
  }

  /// Juspay UPI-intent sheet for the cart (React: setUpiIntentOrder(orderNumber)).
  /// "Pay using" chooser (React `PayUsingSheet`): UPI apps + QR use the Juspay
  /// intent flow; cards / netbanking use the Easebuzz hosted checkout.
  void _showPayUsing(
    BuildContext context,
    WidgetRef ref,
    String orderNumber,
    double cashAmount,
    List<PaymentMethodFee> methods, {
    required CartCheckoutNotifier checkoutNotifier,
    required SuperCoinIdentity? superCoinIdentity,
  }) {
    final router = GoRouter.of(context);
    showPayUsingSheet(
      context: context,
      orderNumber: orderNumber,
      cashAmount: cashAmount,
      methods: methods,
      amountLabel:
          '\u20b9${ref.read(paymentBreakdownProvider).finalPayable.toStringAsFixed(2)}',
      onPaid: (_) => router.go('/orders'),
      onLeavePending: (_) => router.go('/orders'),
      onCardMethod: (code) {
        checkoutNotifier.setSelectedPaymentMethod(code);
        _startHostedPayment(
          context,
          ref,
          orderNumber,
          checkoutNotifier: checkoutNotifier,
          superCoinIdentity: superCoinIdentity,
        ).catchError((e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$e')));
          }
        });
      },
      onFallbackToOtherMethods: () {
        final fallback = methods
            .where((m) => !isUpiPaymentMethod(m.code))
            .toList();
        if (fallback.isNotEmpty) {
          checkoutNotifier.setSelectedPaymentMethod(fallback.first.code);
        }
        _startHostedPayment(
          context,
          ref,
          orderNumber,
          checkoutNotifier: checkoutNotifier,
          superCoinIdentity: superCoinIdentity,
        ).catchError((e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$e')));
          }
        });
      },
    );
  }

  SuperCoinIdentity? _buildSuperCoinIdentity(dynamic user) {
    final normalized = normalizeMobileToE164(user?.mobile);
    if (normalized == null) return null;
    return SuperCoinIdentity(identifier: normalized, type: 'MOBILE');
  }

  Future<void> _failPay(
    BuildContext context,
    WidgetRef ref,
    String message,
    CartCheckoutNotifier checkoutNotifier,
    SuperCoinIdentity? superCoinIdentity,
  ) async {
    // Release any active SuperCoin hold before surfacing the failure.
    await checkoutNotifier.cancelSuperCoinHoldIfNeeded(
      identity: superCoinIdentity,
    );
    checkoutNotifier.setProcessing(false);
    onPaymentComplete();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

/// Pay-confirm step (React cart's payOpen panel): the cash payment method
/// (UPI/DC/CC/NB) is chosen here — only when the user taps Pay — before the
/// payment actually starts.
class _PayConfirmSheet extends ConsumerStatefulWidget {
  final PaymentBreakdown breakdown;
  final List<PaymentMethodFee> methods;
  final String methodLabel;
  final String methodSubtext;
  final String earnText;
  final bool processing;
  final VoidCallback onConfirm;

  const _PayConfirmSheet({
    required this.breakdown,
    required this.methods,
    required this.methodLabel,
    required this.methodSubtext,
    required this.earnText,
    required this.processing,
    required this.onConfirm,
  });

  @override
  ConsumerState<_PayConfirmSheet> createState() => _PayConfirmSheetState();
}

class _PayConfirmSheetState extends ConsumerState<_PayConfirmSheet> {
  @override
  Widget build(BuildContext context) {
    final b = widget.breakdown;
    final totalPay = b.finalPayable;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).padding.bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOU PAY',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\u20b9${totalPay.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9747FF),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.earnText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 14),
          // PayUsingField: one control that opens the "Pay using" chooser.
          GestureDetector(
            onTap: widget.processing ? null : widget.onConfirm,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: widget.processing
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                      ),
                color: widget.processing ? const Color(0xFFD1D5DB) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.processing
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(
                            0xFF6C5CE7,
                          ).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'PAY USING',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_up,
                              size: 14,
                              color: Color(0xB3FFFFFF),
                            ),
                          ],
                        ),
                        Text(
                          widget.methodLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          widget.methodSubtext,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.processing
                        ? 'Please wait.'
                        : 'Pay \u20b9${totalPay.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
