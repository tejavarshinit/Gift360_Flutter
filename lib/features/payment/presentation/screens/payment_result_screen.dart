import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/core/providers/notification_provider.dart';

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
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  bool _isLoading = true;
  bool _statusUpdated = false;
  bool _couponsFetched = false;

  /// The order number this screen is actually operating on, resolved in
  /// [_resolveOrderNumber] — exposed so the "View Order" button etc. can
  /// use the same value the processing logic used.
  String? _resolvedOrderNumber;

  @override
  void initState() {
    super.initState();
    _processPaymentResult();
  }

  /// Mirrors PaymentResult.tsx's "decrypt transaction ID and extract order
  /// number + clientId" effect. The payment gateway callback URL only ever
  /// carries `status` + an encrypted `txnid`/`txnId` — NOT a plain
  /// `orderNumber` — so the order number has to be recovered by decrypting
  /// that token. This works regardless of whether the redirect landed back
  /// inside the same in-app WebView session (which additionally happens to
  /// carry `orderNumber` itself) or via an external/relaunched redirect.
  String? _resolveOrderNumber() {
    final txnId = widget.txnId;
    if (txnId != null && txnId.isNotEmpty) {
      final decrypted = decryptOrderRefFromTxnId(txnId);
      if (decrypted != null) {
        return decrypted.orderNumber;
      }
    }
    // Fall back to whatever the WebView callback carried over in-memory.
    return widget.orderNumber;
  }

  Future<void> _processPaymentResult() async {
    // Simulate loading delay for animation
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final paymentNotifier = ref.read(paymentProvider.notifier);

    // Plain order number (e.g. "ORD260728DA2487BC6FFC") — used for
    // /coupons/fetch, /orders/{orderNumber}, confirmCoupon, and display.
    final orderNumber = _resolveOrderNumber();
    _resolvedOrderNumber = orderNumber;

    // Raw encrypted gateway token — used ONLY for /orders/status's
    // `encryptedData` field, sent verbatim, never decrypted client-side.
    final txnId = widget.txnId;
    final encryptedOrderRef =
        (txnId != null && txnId.isNotEmpty) ? normalizeEncryptedToken(txnId) : null;

    if (orderNumber == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Determine payment status
    final isSuccess = widget.status?.toLowerCase() == 'success';
    final orderStatus = isSuccess ? 'PAID' : 'FAILED';

    // Update order status
    if (!_statusUpdated) {
      bool statusUpdateSucceeded = false;
      if (encryptedOrderRef != null) {
        statusUpdateSucceeded =
            await paymentNotifier.updateOrderStatus(orderStatus, encryptedOrderRef: encryptedOrderRef);
      }
      _statusUpdated = true;

      if (isSuccess && statusUpdateSucceeded) {
        // Confirm coupon reservation (if any) — releases the temporary hold
        await paymentNotifier.confirmCoupon(orderNumber);

        // Trigger voucher/coupon generation for this now-PAID order.
        // Only do this once the status update is confirmed successful —
        // otherwise we'd be generating vouchers for an order the backend
        // never actually marked PAID.
        final clientId = ref.read(authProvider)?.clientId;
        if (clientId != null && clientId.isNotEmpty) {
          await paymentNotifier.fetchCoupons(clientId: clientId, orderNumber: orderNumber);
        }
        _couponsFetched = true;

        // Fetch order details (now that coupons should be generated)
        await paymentNotifier.fetchOrderDetails(orderNumber: orderNumber);

        // Add success notification
        if (mounted) {
          ref.read(notificationProvider.notifier).addNotification(
                title: 'Congratulations!',
                message: 'Your voucher has been purchased successfully',
                type: 'success',
                eventKey: 'purchase-$orderNumber',
              );
        }
      } else if (isSuccess && !statusUpdateSucceeded) {
        // Payment succeeded but we couldn't confirm the order status update.
        // Don't generate vouchers yet — the order may still be processed
        // asynchronously server-side; the user can check Orders later.
      } else {
        // Release coupon on failure
        await paymentNotifier.releaseCoupon();
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);

    final isSuccess = widget.status?.toLowerCase() == 'success';
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
              // Status Icon
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
              // Status Title
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isLoading ? Colors.white : statusColor,
                ),
              ),
              const SizedBox(height: 8),
              // Status Message
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
              // Details Card
              if (!_isLoading)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('Status', statusTitle.toUpperCase(), statusColor),
                        if (_resolvedOrderNumber != null) ...[
                          const Divider(height: 24),
                          _detailRow('Order Number', _resolvedOrderNumber!, Colors.grey.shade700),
                        ],
                        if (isSuccess && paymentState.orderDetails?.coinsEarned != null) ...[
                          const Divider(height: 24),
                          _detailRow('SuperCoins Earned', '${paymentState.orderDetails!.coinsEarned}', const Color(0xFF523DA9)),
                        ],
                        if (isSuccess && _couponsFetched) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                              const SizedBox(width: 8),
                              Text('Voucher sent to your email', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: const Text('View Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: const Text('Return to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Continue Shopping', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF523DA9))),
                        ),
                      ),
                      if (!isSuccess) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {},
                          child: const Text('Contact Support →', style: TextStyle(fontSize: 14, color: Color(0xFF523DA9), fontWeight: FontWeight.w600)),
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
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
