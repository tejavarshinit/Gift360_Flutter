import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/data/models/payment.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/core/widgets/brand_image.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _useWallet = false;
  bool _isProcessing = false;
  final _couponController = TextEditingController();
  String? _appliedCouponCode;
  double _couponDiscount = 0;
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final cart = ref.watch(cartProvider);
    final paymentState = ref.watch(paymentProvider);
    final walletAsync = ref.watch(walletBalanceProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to continue')),
      );
    }

    if (cart == null || cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Your cart is empty')),
      );
    }

    final subtotal = cart.totalAmount;
    final walletBalance = (walletAsync.value?.totalBalance ?? 0).toDouble();
    final maxWalletUsage = subtotal * 0.5;
    final walletDeduction = _useWallet ? (walletBalance < maxWalletUsage ? walletBalance : maxWalletUsage) : 0.0;
    final finalPayable = subtotal - _couponDiscount - walletDeduction;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Order Summary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF523DA9), Color(0xFF4C42B8), Color(0xFF5365DF)]),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCartItems(cart.items),
                  const SizedBox(height: 16),
                  _buildWalletSection(walletBalance, maxWalletUsage),
                  const SizedBox(height: 12),
                  _buildCouponSection(paymentState),
                  const SizedBox(height: 12),
                  _buildOrderSummary(subtotal, walletDeduction, finalPayable),
                ],
              ),
            ),
          ),
          _buildPayButton(finalPayable, user, cart.items, paymentState),
        ],
      ),
    );
  }

  Widget _buildCartItems(List items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Cart Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...items.map((item) => _buildCartItem(item)),
        ],
      ),
    );
  }

  Widget _buildCartItem(dynamic item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BrandImage(
              imageUrl: item.image ?? '',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                width: 56, height: 56,
                color: Colors.grey.shade100,
                child: const Icon(Icons.card_giftcard, color: Colors.grey),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 56, height: 56,
                color: Colors.grey.shade100,
                child: const Icon(Icons.card_giftcard, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.brandName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text('₹${item.unitValue.toStringAsFixed(2)} × ${item.quantity}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Text('₹${item.lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF523DA9), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildWalletSection(double walletBalance, double maxWalletUsage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Checkbox(
            value: _useWallet,
            onChanged: walletBalance <= 0 ? null : (v) => setState(() => _useWallet = v ?? false),
            activeColor: const Color(0xFF523DA9),
          ),
          const Icon(Icons.account_balance_wallet, color: Color(0xFF523DA9), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Use Wallet Balance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Available: ₹${walletBalance.toStringAsFixed(2)} • Max: ₹${maxWalletUsage.toStringAsFixed(2)} (50%)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(PaymentState paymentState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: Color(0xFF523DA9), size: 18),
              const SizedBox(width: 8),
              const Text('Apply Coupon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (_appliedCouponCode != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$_appliedCouponCode applied (-₹${_couponDiscount.toStringAsFixed(2)})',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _appliedCouponCode = null;
                      _couponDiscount = 0;
                      _couponController.clear();
                    }),
                    child: Icon(Icons.close, color: Colors.green.shade700, size: 18),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: paymentState.isLoading ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF523DA9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          if (_couponError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_couponError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(double subtotal, double walletDeduction, double finalPayable) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
          if (walletDeduction > 0)
            _summaryRow('Wallet Deduction', '-₹${walletDeduction.toStringAsFixed(2)}', color: Colors.green),
          if (_couponDiscount > 0)
            _summaryRow('Coupon Discount', '-₹${_couponDiscount.toStringAsFixed(2)}', color: const Color(0xFF523DA9)),
          const Divider(height: 24),
          _summaryRow('Total to Pay', '₹${finalPayable.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF523DA9)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 14,
            color: color,
          )),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 18 : 14,
            color: color,
          )),
        ],
      ),
    );
  }

  Widget _buildPayButton(double finalPayable, dynamic user, List items, PaymentState paymentState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total to Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('₹${finalPayable.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF523DA9))),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _handlePayNow(finalPayable, user, items),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF523DA9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Pay with SabbPe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _couponError = null;
      _isProcessing = true;
    });

    try {
      final user = ref.read(authProvider);
      final cart = ref.read(cartProvider);
      if (user == null || cart == null) return;

      final paymentNotifier = ref.read(paymentProvider.notifier);

      // First ensure order exists
      if (!ref.read(paymentProvider).orderCreated) {
        final items = cart.items.map((item) => {
          'brandId': item.brandId,
          'quantity': item.quantity,
          'unitValue': item.unitValue,
          'lineTotal': item.lineTotal,
          'meta': {'brand_id': item.brandId, 'brand_name': item.brandName},
        }).toList();

        final created = await paymentNotifier.createOrder(
          clientId: user.clientId,
          items: List<Map<String, dynamic>>.from(items),
          totalAmount: cart.totalAmount,
          walletUsed: _useWallet,
          walletAmount: _useWallet ? (ref.read(walletBalanceProvider).value?.totalBalance ?? 0) * 0.5 : 0,
        );

        if (created == null) {
          setState(() {
            _couponError = 'Failed to create order';
            _isProcessing = false;
          });
          return;
        }
      }

      final orderNumber = ref.read(paymentProvider).orderNumber;
      if (orderNumber == null) {
        setState(() {
          _couponError = 'Order not found';
          _isProcessing = false;
        });
        return;
      }

      final couponItems = cart.items.map((item) => CouponItem(
        brandName: item.brandName,
        quantity: item.quantity,
        unitValue: item.unitValue,
      )).toList();

      final response = await paymentNotifier.validateCoupon(CouponValidateRequest(
        couponCode: code.toUpperCase(),
        orderId: orderNumber,
        clientId: user.clientId,
        items: couponItems,
        subtotal: cart.totalAmount,
        fee: 0,
      ));

      if (response != null && response.reservationId != null) {
        setState(() {
          _appliedCouponCode = code.toUpperCase();
          _couponDiscount = response.discount;
          _couponError = null;
        });
      } else {
        setState(() {
          _couponError = 'Invalid coupon code';
        });
      }
    } catch (e) {
      setState(() {
        _couponError = 'Coupon validation failed';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePayNow(double finalPayable, dynamic user, List items) async {
    setState(() => _isProcessing = true);

    try {
      final paymentNotifier = ref.read(paymentProvider.notifier);
      final cart = ref.read(cartProvider);

      // Step 1: Create order
      if (!ref.read(paymentProvider).orderCreated) {
        final orderItems = items.map((item) => {
          'brandId': item.brandId,
          'quantity': item.quantity,
          'unitValue': item.unitValue,
          'lineTotal': item.lineTotal,
          'meta': {'brand_id': item.brandId, 'brand_name': item.brandName},
        }).toList();

      final walletAmount = _useWallet ? (ref.read(walletBalanceProvider).value?.totalBalance ?? 0).toDouble() * 0.5 : 0.0;

        final created = await paymentNotifier.createOrder(
          clientId: user.clientId,
          items: List<Map<String, dynamic>>.from(orderItems),
          totalAmount: cart!.totalAmount,
          walletUsed: _useWallet,
          walletAmount: walletAmount,
        );

        if (created == null || !mounted) {
          setState(() => _isProcessing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create order')),
            );
          }
          return;
        }
      }

      // Step 2: Validate order
      final walletAmount = _useWallet ? (ref.read(walletBalanceProvider).value?.totalBalance ?? 0).toDouble() * 0.5 : 0.0;
      final validated = await paymentNotifier.validateOrder(
        cartTotal: cart!.totalAmount,
        walletAmount: walletAmount,
        walletUsed: _useWallet,
      );

      if (!validated || !mounted) {
        setState(() => _isProcessing = false);
        if (mounted) {
          final msg = ref.read(paymentProvider).error ?? 'Order validation failed';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }

      // Step 3: Generate token
      final tokenGenerated = await paymentNotifier.generateToken();
      if (!tokenGenerated || !mounted) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate payment token')),
          );
        }
        return;
      }

      // Step 4: Encrypt order ref
      final currentOrderNumber = ref.read(paymentProvider).orderNumber ?? '';
      final encryptedOrderRef = encryptOrderRef(currentOrderNumber, user.clientId);

      // Step 5: Initiate payment
      final productInfo = items.map((i) => i.brandName).join(', ');
      final initiated = await paymentNotifier.initiatePayment(
        amount: finalPayable,
        productInfo: productInfo.isNotEmpty ? productInfo : AppConfig.paymentProductInfo,
        frontendUrl: AppConfig.sabbpeFrontendUrl,
        customer: CustomerInfo(
          firstname: AppConfig.paymentCustFirstName,
          email: AppConfig.paymentCustEmail,
          phone: AppConfig.paymentCustMobile,
        ),
        encryptedOrderRef: encryptedOrderRef,
        clientId: user.clientId,
      );

      if (!initiated || !mounted) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initiate payment')),
          );
        }
        return;
      }

      // Step 5: Navigate to payment WebView
      final paymentUrl = ref.read(paymentProvider).initiateResponse?.paymentUrl;
      if (paymentUrl != null && mounted) {
        ref.read(cartProvider.notifier).clearCart();
        context.push('/payment-webview', extra: {
          'paymentUrl': paymentUrl,
          'orderNumber': ref.read(paymentProvider).orderNumber,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }
  }
}
