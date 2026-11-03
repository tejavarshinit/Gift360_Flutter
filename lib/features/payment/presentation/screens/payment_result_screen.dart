import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/data/repositories/session_resume_api.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/core/utils/analytics.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/core/providers/notification_provider.dart';
import 'package:gift360/core/widgets/gift_header.dart';
import 'package:gift360/core/widgets/site_footer.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/rewards/presentation/providers/rewards_provider.dart';
import 'package:gift360/features/rewards/presentation/widgets/quiz_modal.dart';
import 'package:gift360/features/feedback/presentation/feedback_orchestrator.dart';

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
  bool _orderDetailsLoading = false;
  bool _orderDetailsLoaded = false;

  /// Live processing status indicators (matches React's step-by-step UI)
  bool _statusUpdateInProgress = false;
  bool _couponConfirmInProgress = false;
  bool _fetchCouponsInProgress = false;
  bool _fetchCouponsDone = false;
  final bool _fetchCouponsFailed = false;

  String? _resolvedOrderNumber;
  String? _resolvedClientId;

  /// Session resume from the encrypted order reference (`txnid`).
  Future<void>? _resumeFuture;

  /// Payment-cancelled Dussehra quiz callout (mirrors React PaymentResult).
  bool _cancelCalloutAttempted = false;
  bool _calloutLoading = false;
  Map<String, dynamic>? _calloutReward;
  int _calloutSecondsLeft = 0;
  Timer? _calloutTimer;
  static const int _voucherRedirectSeconds = 10;
  int _voucherSecondsLeft = _voucherRedirectSeconds;
  bool _stayOnResult = false;
  Timer? _voucherRedirectTimer;

  @override
  void initState() {
    super.initState();
    hideGlobalSupportChat();
    _resumeFuture = _resumeSessionForReturn();
    _processPaymentResult();

    // Payment cancelled by the customer: offer the feedback form shortly after
    // the result page renders (the orchestrator applies cooldowns/limits).
    if (widget.status?.toLowerCase() == 'usercancelled') {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          FeedbackOrchestrator.prompt(context, ref, 'payment-cancelled');
        }
      });
    }
  }

  @override
  void dispose() {
    showGlobalSupportChat();
    _calloutTimer?.cancel();
    _voucherRedirectTimer?.cancel();
    super.dispose();
  }

  void _startVoucherRedirect() {
    if (_voucherRedirectTimer != null || _stayOnResult) return;

    _voucherRedirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_voucherSecondsLeft <= 1) {
        timer.cancel();
        _voucherRedirectTimer = null;
        _navigateToVouchers();
        return;
      }
      setState(() => _voucherSecondsLeft--);
    });
  }

  Future<void> _navigateToVouchers() async {
    _voucherRedirectTimer?.cancel();
    _voucherRedirectTimer = null;
    await PaymentNotifier.setJustReturnedFromPayment();
    if (mounted) context.go('/orders');
  }

  void _stayOnPaymentResult() {
    _voucherRedirectTimer?.cancel();
    _voucherRedirectTimer = null;
    setState(() => _stayOnResult = true);
  }

  /// Restore the customer's existing session from the encrypted order reference
  /// in the return URL. This does NOT depend on local storage, so it works even
  /// when the page loads in a different/empty browser context (e.g. Google
  /// Pay's in-app browser after a UPI hand-off). Never logs the user out: any
  /// failure is ignored and the page stays read-only.
  Future<void> _resumeSessionForReturn() async {
    final txnId = widget.txnId;
    if (txnId == null || txnId.trim().isEmpty) return;

    final session = await SessionResumeApi().resume(
      normalizeEncryptedToken(txnId),
    );
    if (session == null) return;

    final token = (session['token'] ?? '').toString();
    final info = (session['userInfo'] as Map?)?.cast<String, dynamic>();
    if (token.isEmpty || info == null) return;

    final resumed = AuthUser(
      name: (info['name'] ?? '').toString(),
      email: (info['email'] ?? '').toString(),
      mobile: (info['mobile'] ?? '').toString(),
      token: token,
      clientId: (info['clientId'] ?? '').toString(),
    );

    // Only adopt the resumed session when there is no in-app session or it is
    // the same customer — avoids silently switching accounts.
    final current = ref.read(authProvider);
    if (current != null &&
        current.clientId.isNotEmpty &&
        current.clientId != resumed.clientId) {
      return;
    }
    if (!mounted) return;
    ref.read(authProvider.notifier).setUser(resumed);
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

    // Ensure the session restore has completed before the order calls, so they
    // carry the restored Bearer token (avoids a token-less 401).
    if (_resumeFuture != null) {
      try {
        await _resumeFuture;
      } catch (_) {}
    }
    if (!mounted) return;

    final paymentNotifier = ref.read(paymentProvider.notifier);

    final hasTxnId = widget.txnId != null && widget.txnId!.isNotEmpty;
    final isSuccess =
        widget.status?.toLowerCase() == 'success' ||
        (hasTxnId && widget.status == null && widget.error == null);
    final orderNumber = _resolveOrderNumber();
    _resolvedOrderNumber = orderNumber;

    final txnId = widget.txnId;
    final encryptedOrderRef = (txnId != null && txnId.isNotEmpty)
        ? normalizeEncryptedToken(txnId)
        : null;

    if (orderNumber == null) {
      setState(() {
        _isLoading = false;
        if (isSuccess) _orderDetailsLoaded = true;
      });
      if (isSuccess) _startVoucherRedirect();
      return;
    }

    _validateClientId();

    final isCancelled = widget.status?.toLowerCase() == 'usercancelled';
    final orderStatus = isSuccess ? 'PAID' : 'FAILED';

    if (!_statusUpdated) {
      setState(() {
        _statusUpdateInProgress = true;
        _isLoading = false;
      });
      if (isSuccess) _startVoucherRedirect();

      bool statusUpdateSucceeded = false;
      // A customer cancellation stays read-only (matches React): the order must
      // remain PENDING for the Dussehra quiz offer to be registered.
      if (encryptedOrderRef != null && !isCancelled) {
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
        if (mounted) setState(() => _orderDetailsLoading = true);
        try {
          await paymentNotifier.fetchOrderDetails(orderNumber: orderNumber);
        } finally {
          if (mounted) {
            setState(() {
              _orderDetailsLoading = false;
              _orderDetailsLoaded = true;
            });
          }
        }

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
        if (mounted) setState(() => _orderDetailsLoaded = true);
      } else {
        await paymentNotifier.releaseCoupon();
        await SuperCoinOtpNotifier.clearHoldContext(orderNumber);
        await SuperCoinOtpNotifier.clearActiveOrderNumber();
      }

      // Payment cancelled: offer the Dussehra quiz callout (source of truth for
      // opening the offer is the backend, which verifies the order is PENDING).
      if (isCancelled) {
        await _handleCancelledOrder(orderNumber);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (isSuccess) _startVoucherRedirect();
    }
  }

  /// Registers the payment-cancelled Dussehra quiz offer and shows the callout.
  /// Mirrors React `registerPaymentCancellation` usage in PaymentResult.
  Future<void> _handleCancelledOrder(String orderNumber) async {
    if (_cancelCalloutAttempted) return;
    _cancelCalloutAttempted = true;

    final clientId = ref.read(authProvider)?.clientId;
    if (clientId == null || clientId.isEmpty) return;

    if (mounted) setState(() => _calloutLoading = true);
    try {
      await ref
          .read(paymentProvider.notifier)
          .fetchOrderDetails(orderNumber: orderNumber);
      final status = ref
          .read(paymentProvider)
          .orderDetails
          ?.status
          ?.toUpperCase();
      if (status != 'PENDING') {
        if (mounted) setState(() => _calloutLoading = false);
        return;
      }

      final reward = await ref
          .read(rewardsApiProvider)
          .registerPaymentCancellation(clientId, orderNumber);
      if (!mounted) return;
      setState(() {
        _calloutReward = reward;
        _calloutLoading = false;
      });
      _startCalloutCountdown(reward['quizStartExpiresAt']?.toString());
    } catch (_) {
      if (mounted) setState(() => _calloutLoading = false);
    }
  }

  void _startCalloutCountdown(String? deadlineIso) {
    _calloutTimer?.cancel();
    final deadline = DateTime.tryParse(deadlineIso ?? '');
    if (deadline == null) return;

    void tick() {
      if (!mounted) return;
      final left = deadline.difference(DateTime.now()).inSeconds;
      setState(() => _calloutSecondsLeft = left > 0 ? left : 0);
    }

    tick();
    _calloutTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _openCancelledQuiz() async {
    final publicId = (_calloutReward?['publicId'] ?? '').toString();
    final clientId = ref.read(authProvider)?.clientId ?? '';
    if (publicId.isEmpty || clientId.isEmpty) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuizModal(
        clientId: clientId,
        publicId: publicId,
        onClose: () => Navigator.of(context, rootNavigator: true).pop(),
        onFinished: (reward) {
          ref.invalidate(rewardStatusProvider);
          if (mounted) {
            setState(() {
              _calloutReward = {...?_calloutReward, ...reward};
            });
          }
        },
      ),
    );
  }

  Widget _buildCancelCallout() {
    final reward = _calloutReward!;
    final status = (reward['status'] ?? '').toString().toUpperCase();
    final available = status == 'AVAILABLE' || status == 'IN_PROGRESS';
    final pending = status == 'PENDING';
    final minutes = _calloutSecondsLeft ~/ 60;
    final seconds = (_calloutSecondsLeft % 60).toString().padLeft(2, '0');
    final hasPublicId = (reward['publicId'] ?? '').toString().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: available
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment cancelled? Play a quick Dussehra quiz and earn 5 SuperCoins!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF431407),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start and finish within $minutes:$seconds.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7C2D12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _calloutSecondsLeft <= 0 || !hasPublicId
                        ? null
                        : _openCancelledQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Play Dussehra Quiz',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Text(
              pending
                  ? 'Quiz won! Complete a new purchase within five minutes to receive 5 bonus SuperCoins after payment and voucher fulfillment.'
                  : 'This Dussehra quiz offer has expired or is no longer available.',
              style: TextStyle(
                fontSize: pending ? 13 : 12,
                fontWeight: pending ? FontWeight.w600 : FontWeight.w500,
                color: pending
                    ? const Color(0xFF431407)
                    : const Color(0xFF7C2D12),
              ),
            ),
    );
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

    if (!_isLoading) {
      return isSuccess
          ? _buildSuccessResult(paymentState)
          : _buildGenericResult(
              isPending: isPending,
              isCancelled: isCancelled,
              statusColor: statusColor,
              statusIcon: statusIcon,
              statusTitle: statusTitle,
              statusMessage: statusMessage,
            );
    }

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

                          // Payment-cancelled quiz callout
                          if (isCancelled && _calloutLoading) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFEA580C),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Preparing your Dussehra quiz offer.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF7C2D12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isCancelled && _calloutReward != null) ...[
                            const SizedBox(height: 12),
                            _buildCancelCallout(),
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

  Widget _buildSuccessResult(PaymentState paymentState) {
    final orderDetails = paymentState.orderDetails;
    final coins = orderDetails?.coinsEarned ?? 0;
    final cashback = orderDetails?.cashbackEarned ?? 0;
    final hasCoins = coins > 0;
    final hasCashback = cashback > 0;
    final rewardsKnown = hasCoins || hasCashback;
    final showSkeleton =
        !rewardsKnown &&
        (_orderDetailsLoading ||
            _statusUpdateInProgress ||
            _couponConfirmInProgress ||
            _fetchCouponsInProgress ||
            (orderDetails == null && !_orderDetailsLoaded));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4ECFF), Colors.white],
            stops: [0, 0.4],
          ),
        ),
        child: Column(
          children: [
            const GiftHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.4, end: 1),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.elasticOut,
                                builder: (context, scale, child) =>
                                    Transform.scale(scale: scale, child: child),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF34D399),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.35),
                                        blurRadius: 28,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Payment successful',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F1B3A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your vouchers are being issued${_resolvedOrderNumber == null ? '' : ' · Order #$_resolvedOrderNumber'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (showSkeleton)
                                _rewardSkeleton()
                              else if (hasCoins || hasCashback) ...[
                                if (hasCoins)
                                  _successRewardCard(
                                    color: const Color(0xFF7C3AED),
                                    borderColor: const Color(0xFFD8B4FE),
                                    backgroundColor: const Color(0xFFF5F3FF),
                                    icon: Image.asset(
                                      'assets/images/SuperCOin-removebg-preview.png',
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.contain,
                                    ),
                                    value: coins.toDouble(),
                                    label: 'SuperCoins',
                                    detail:
                                        'Added to your Flipkart SuperCoin account',
                                  ),
                                if (hasCashback) ...[
                                  if (hasCoins) const SizedBox(height: 12),
                                  _successRewardCard(
                                    color: const Color(0xFF059669),
                                    borderColor: const Color(0xFFA7F3D0),
                                    backgroundColor: const Color(0xFFECFDF5),
                                    icon: const Text(
                                      '💰',
                                      style: TextStyle(fontSize: 32),
                                    ),
                                    value: cashback,
                                    label: 'cashback points',
                                    detail:
                                        '1 point = ₹1 · already in your wallet',
                                  ),
                                ],
                              ] else if (_orderDetailsLoaded)
                                _successInfoCard(
                                  'Any rewards from this order will show in your wallet once it is processed.',
                                ),
                              const SizedBox(height: 20),
                              if (!_stayOnResult)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value:
                                                _voucherSecondsLeft /
                                                _voucherRedirectSeconds,
                                            strokeWidth: 4,
                                            backgroundColor: const Color(
                                              0xFFE9D5FF,
                                            ),
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                  Color(0xFF7C3AED),
                                                ),
                                          ),
                                          Text(
                                            '$_voucherSecondsLeft',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4C1D95),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Taking you to your\nvouchers in ${_voucherSecondsLeft}s',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Text(
                                  'Your vouchers will appear on the Orders page once issued.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 240,
                                height: 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF7B61FF),
                                        Color(0xFF5B3FFF),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF6C5CE7,
                                        ).withValues(alpha: 0.28),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _navigateToVouchers,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: const StadiumBorder(),
                                    ),
                                    child: const Text(
                                      'View my vouchers',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 24,
                                children: [
                                  TextButton(
                                    onPressed: () => context.go('/'),
                                    child: const Text(
                                      'Continue shopping',
                                      style: TextStyle(
                                        color: Color(0xFF5B3FFF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (!_stayOnResult)
                                    TextButton(
                                      onPressed: _stayOnPaymentResult,
                                      child: const Text(
                                        'Stay here',
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SiteFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successRewardCard({
    required Color color,
    required Color borderColor,
    required Color backgroundColor,
    required Widget icon,
    required double value,
    required String label,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: 56, height: 56, child: Center(child: icon)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOU EARNED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (context, currentValue, child) => Text(
                    '+${_formatReward(currentValue, value)} $label',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardSkeleton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE9FE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF7C3AED),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Counting your rewards…',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successInfoCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE9FE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
      ),
    );
  }

  String _formatReward(double value, double finalValue) =>
      finalValue % 1 == 0 ? value.round().toString() : value.toStringAsFixed(2);

  Widget _buildGenericResult({
    required bool isPending,
    required bool isCancelled,
    required Color statusColor,
    required IconData statusIcon,
    required String statusTitle,
    required String statusMessage,
  }) {
    final statusLabel = isPending ? 'PENDING' : 'FAILED';
    final hasTransaction = widget.txnId?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4ECFF), Colors.white],
            stops: [0, 0.4],
          ),
        ),
        child: Column(
          children: [
            const GiftHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672),
                          child: Card(
                            elevation: 12,
                            shadowColor: const Color(0x26000000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                28,
                                24,
                                24,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 80,
                                    color: statusColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    statusTitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    statusMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isCancelled && _calloutLoading) ...[
                                          const Row(
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFFEA580C),
                                                    ),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Preparing your Dussehra quiz offer…',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF7C2D12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        if (isCancelled &&
                                            _calloutReward != null) ...[
                                          _buildCancelCallout(),
                                          const SizedBox(height: 12),
                                        ],
                                        _detailRow(
                                          'Status',
                                          statusLabel,
                                          statusColor,
                                        ),
                                        if (_resolvedOrderNumber != null) ...[
                                          const Divider(height: 24),
                                          _detailRow(
                                            'Order Number',
                                            _resolvedOrderNumber!,
                                            const Color(0xFF4B5563),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!hasTransaction) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFDE68A),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Text(
                                        '⚠️ Transaction details unavailable. Please contact support with your payment reference.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: () => context.go('/cart'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF7B61FF,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Return to Cart',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () => context.go('/'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF5B3FFF,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFD1D5DB),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Go to Home',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isPending) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Divider(height: 1),
                                    ),
                                    const Text(
                                      'Need assistance with your payment?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _launchSupport,
                                      child: const Text(
                                        'Contact Support →',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SiteFooter(),
                  ],
                ),
              ),
            ),
          ],
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
