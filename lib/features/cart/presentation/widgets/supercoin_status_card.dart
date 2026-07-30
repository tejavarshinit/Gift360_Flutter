import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';

class SuperCoinStatusCard extends ConsumerWidget {
  final double maxRedeemable;
  final double estimatedEarn;
  final bool hideToggle;
  final void Function({required bool eligible, required double balance, required bool enabled})? onStateChange;

  const SuperCoinStatusCard({
    super.key,
    required this.maxRedeemable,
    required this.estimatedEarn,
    this.hideToggle = false,
    this.onStateChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final superCoinState = ref.watch(supercoinProvider);

    // Report state changes
    if (onStateChange != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onStateChange!(
          eligible: superCoinState.isEnrolled && superCoinState.balance > 0,
          balance: superCoinState.balance,
          enabled: false,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Flipkart branding
        Row(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/SuperCOin-removebg-preview.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'SuperCoin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5B3FFF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Save more with SuperCoins',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Powered by Flipkart',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Main card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            children: [
              // Loading
              if (superCoinState.isSearching || superCoinState.isBalanceLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6D5AE6)),
                    ),
                  ),
                ),

              // No identity
              if (!superCoinState.isSearching && !superCoinState.isBalanceLoading && !superCoinState.isEnrolled)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    superCoinState.error != null
                        ? 'SuperCoin is unavailable at the moment. You can still continue with your purchase.'
                        : 'Register on Flipkart SuperCoin to earn & redeem coins on every purchase.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),

              // Enrolled content
              if (superCoinState.isEnrolled && !superCoinState.isSearching) ...[
                // Usage info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your SuperCoin balance: ${superCoinState.balance.toStringAsFixed(2)} coins',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          if (maxRedeemable > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Max redeemable: ${maxRedeemable.toStringAsFixed(2)} coins',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Error
                if (superCoinState.error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      superCoinState.error!,
                      style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                    ),
                  ),
                ],
              ],

              // Earn section
              if (superCoinState.isEnrolled && estimatedEarn > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/SuperCOin-removebg-preview.png',
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'You will earn ${estimatedEarn.toStringAsFixed(2)} coins',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      ),
                      const Spacer(),
                      const Text('EARN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
