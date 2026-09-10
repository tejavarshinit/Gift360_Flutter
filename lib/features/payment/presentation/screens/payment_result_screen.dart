import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/core/utils/analytics.dart';
import 'package:gift360/core/providers/notification_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';

class PaymentResultScreen extends ConsumerStatefulWidget {
  final String? status;
  final String? txnId;
  final String? error;
  final String? orderNumber;

  const PaymentResultScreen({
    super.key,
    this.status,
    this.txnId,
    this.error,
    this.orderNumber,
  });

  @override
  ConsumerState<PaymentResultScreen> createState() =>
      _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  bool _isLoading = true;
  bool _statusUpdated = false;
  bool _couponsFetched = false;
  bool _clientIdMismatch = false;

  /// Live processing status indicators (matches React's step-by-step UI)
  bool _statusUpdateInProgress = false;
  bool _couponConfirmInProgress = false;
  bool _couponConfirmDone = false;
  bool _fetchCouponsInProgress = false;
  bool _fetchCouponsDone = false;
  bool _fetchCouponsFailed = false;

  String? _resolvedOrderNumber;
  String? _resolvedClientId;

  @override
  void initState() {
    super.initState();
    _processPaymentResult();
  }

  String? _resolveOrderNumber() {
    final txnId = widget.txnId;
    if (txnId != null && txnId.isNotEmpty) {
      final decrypted = decryptOrderRefFromTxnId(txnId);
      if (decrypted != null) {
        _resolvedClientId = decrypted.clientId;
        return decrypted.orderNumber;
      }
    }
    return widget.orderNumber;
  }

  /// Validate clientId from decrypted token matches the logged-in user.
  void _validateClientId() {
    final userClientId = ref.read(authProvider)?.clientId;
    final tokenClientId = _resolvedClientId;
    if (tokenClientId != null &&
        tokenClientId.isNotEmpty &&
        userClientId != null &&
        userClientId.isNotEmpty &&
        tokenClientId != userClientId) {
      _clientIdMismatch = true;
    } else {
      _clientIdMismatch = false;
    }
  }

  Future<void> _processPaymentResult() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final paymentNotifier = ref.read(paymentProvider.notifier);

    final orderNumber = _resolveOrderNumber();
    _resolvedOrderNumber = orderNumber;

    final txnId = widget.txnId;
    final encryptedOrderRef = (txnId != null && txnId.isNotEmpty)
        ? normalizeEncryptedToken(txnId)
        : null;

    if (orderNumber == null) {
      setState(() => _isLoading = false);
      return;
    }

    _validateClientId();

    final hasTxnId = widget.txnId != null && widget.txnId!.isNotEmpty;
    final isSuccess =
        widget.status?.toLowerCase() == 'success' ||
        (hasTxnId && widget.status == null && widget.error == null);
    final orderStatus = isSuccess ? 'PAID' : 'FAILED';

    if (!_statusUpdated) {
      setState(() {
        _statusUpdateInProgress = true;
        _isLoading = false;
      });

      bool statusUpdateSucceeded = false;
      if (encryptedOrderRef != null) {
        statusUpdateSucceeded = await paymentNotifier.updateOrderStatus(
          orderStatus,
          encryptedOrderRef: encryptedOrderRef,
        );
      }

      setState(() {
        _statusUpdateInProgress = false;
        _statusUpdated = true;
      });

      if (isSuccess && statusUpdateSucceeded) {
        // Confirm coupon reservation
        setState(() => _couponConfirmInProgress = true);
        await paymentNotifier.confirmCoupon(orderNumber);
        setState(() {
          _couponConfirmInProgress = false;
          _couponConfirmDone = true;
        });

        // Fetch/generate vouchers
        setState(() => _fetchCouponsInProgress = true);
        final clientId = ref.read(authProvider)?.clientId;
        if (clientId != null && clientId.isNotEmpty) {
          await paymentNotifier.fetchCoupons(
            clientId: clientId,
            orderNumber: orderNumber,
          );
        }
        setState(() {
          _fetchCouponsInProgress = false;
          _fetchCouponsDone = true;
          _couponsFetched = true;
        });

        // Fetch order details (for SuperCoins earned + cashback earned)
        await paymentNotifier.fetchOrderDetails(orderNumber: orderNumber);

        // Clear cart
        if (mounted) {
          ref.read(cartProvider.notifier).clearCart();
          await PaymentNotifier.setJustReturnedFromPayment();
        }

        // Clear SuperCoin hold
        await SuperCoinOtpNotifier.clearHoldContext(orderNumber);
        await SuperCoinOtpNotifier.clearActiveOrderNumber();

        // Refresh balances
        ref.invalidate(walletBalanceProvider);
        await ref.read(supercoinProvider.notifier).fetchBalance();

        // Fire GA4 purchase
        AnalyticsService.trackPurchase(
          orderId: orderNumber,
          value: 0,
          items: [],
        );

        // Success notification
        if (mounted) {
          ref
              .read(notificationProvider.notifier)
              .addNotification(
                title: 'Congratulations!',
                message: 'Your voucher has been purchased successfully',
                type: 'success',
                eventKey: 'purchase-$orderNumber',
              );
        }
      } else if (isSuccess && !statusUpdateSucceeded) {
        await SuperCoinOtpNotifier.clearHoldContext(orderNumber);
        await SuperCoinOtpNotifier.clearActiveOrderNumber();
      } else {
        await paymentNotifier.releaseCoupon();
        await SuperCoinOtpNotifier.clearHoldContext(orderNumber);
        await SuperCoinOtpNotifier.clearActiveOrderNumber();
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);

    final hasTxnId = widget.txnId != null && widget.txnId!.isNotEmpty;
    final isSuccess =
        widget.status?.toLowerCase() == 'success' ||
        (hasTxnId && widget.status == null && widget.error == null);
    final isPending = widget.status?.toLowerCase() == 'pending';
    final isCancelled = widget.status?.toLowerCase() == 'usercancelled';

    final statusColor = isSuccess
        ? Colors.green
        : isPending
        ? Colors.orange
        : Colors.red;

    final statusIcon = isSuccess
        ? Icons.check_circle
        : isPending
        ? Icons.access_time
        : Icons.cancel;

    final statusTitle = _isLoading
        ? 'Processing...'
        : isSuccess
        ? 'Payment Successful'
        : isPending
        ? 'Payment Pending'
        : 'Payment Failed';

    final statusMessage = _isLoading
        ? 'Please wait while we confirm your payment'
        : isSuccess
        ? 'Your payment has been processed successfully!'
        : isCancelled
        ? 'Payment was cancelled. You have not been charged.'
        : widget.error != null
        ? 'Payment verification failed. Please contact support.'
        : 'Payment could not be completed. Please try again.';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF523DA9), Color(0xFF4C42B8), Colors.white],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              _isLoading
                  ? const SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 4,
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.15),
                      ),
                      child: Icon(statusIcon, size: 60, color: statusColor),
                    ),
              const SizedBox(height: 24),
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isLoading ? Colors.white : statusColor,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _isLoading ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (!_isLoading)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow(
                            'Status',
                            statusTitle.toUpperCase(),
                            statusColor,
                          ),
                          if (_resolvedOrderNumber != null) ...[
                            const Divider(height: 24),
                            _detailRow(
                              'Order Number',
                              _resolvedOrderNumber!,
                              Colors.grey.shade700,
                            ),
                          ],

                          // SuperCoins earned
                          if (isSuccess &&
                              paymentState.orderDetails?.coinsEarned !=
                                  null) ...[
                            const Divider(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF523DA9,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF523DA9,
                                  ).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.monetization_on,
                                        size: 16,
                                        color: Color(0xFF523DA9),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'SuperCoin Reward',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You earned ${paymentState.orderDetails!.coinsEarned} SuperCoins for this order.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF523DA9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Cashback earned
                          if (isSuccess &&
                              paymentState.orderDetails?.cashbackEarned !=
                                  null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '💰',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Cashback Reward',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You earned ₹${paymentState.orderDetails!.cashbackEarned} cashback for this order. It\'s already in your wallet.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Voucher confirmation status
                          if (isSuccess && _couponsFetched) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Voucher sent to your email',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Client ID mismatch warning
                          if (_clientIdMismatch) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Client ID mismatch detected. Please contact support.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // Live processing status indicators (during processing)
              if (!_isLoading && hasTxnId && (isSuccess || isPending))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Order status update
                      if (_statusUpdated || _statusUpdateInProgress)
                        _processingStep(
                          inProgress: _statusUpdateInProgress,
                          done: _statusUpdated && !_statusUpdateInProgress,
                          failed: false,
                          label: _statusUpdateInProgress
                              ? 'Confirming order...'
                              : 'Order confirmed',
                        ),
                      // Voucher generation
                      if (_statusUpdated && isSuccess) ...[
                        const SizedBox(height: 8),
                        _processingStep(
                          inProgress: _fetchCouponsInProgress,
                          done: _fetchCouponsDone,
                          failed: _fetchCouponsFailed,
                          label: _fetchCouponsInProgress
                              ? 'Generating vouchers...'
                              : _fetchCouponsDone
                              ? 'Vouchers sent to your email'
                              : 'Vouchers being processed',
                        ),
                      ],
                    ],
                  ),
                ),

              // Action Buttons
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (isSuccess)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => context.go('/orders'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF523DA9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'View Orders',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => context.go('/cart'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF523DA9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Return to Cart',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => context.go('/'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF523DA9)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continue Shopping',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF523DA9),
                            ),
                          ),
                        ),
                      ),
                      if (!isSuccess) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _launchSupport(),
                          child: const Text(
                            'Contact Support →',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF523DA9),
                              fontWeight: FontWeight.w600,
                            ),
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
    );
  }

  Widget _detailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _processingStep({
    required bool inProgress,
    required bool done,
    required bool failed,
    required String label,
  }) {
    final Color color;
    final IconData icon;

    if (inProgress) {
      color = const Color(0xFF523DA9);
      icon = Icons.hourglass_empty;
    } else if (failed) {
      color = Colors.yellow.shade700;
      icon = Icons.access_time;
    } else {
      color = Colors.green.shade600;
      icon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (inProgress)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: done ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchSupport() async {
    final uri = Uri.parse('mailto:support@sabbpe.com');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email client')),
        );
      }
    }
  }
}
