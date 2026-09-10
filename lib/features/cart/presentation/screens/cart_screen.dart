import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_checkout_provider.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/cart/presentation/widgets/cart_item_card.dart';
import 'package:gift360/features/cart/presentation/widgets/cart_tabs.dart';
import 'package:gift360/features/cart/presentation/widgets/order_summary_section.dart';
import 'package:gift360/features/cart/presentation/widgets/supercoin_otp_modal.dart';
import 'package:gift360/features/cart/presentation/widgets/payment_flow_sheet.dart';
import 'package:gift360/features/cart/presentation/widgets/delete_confirm_dialog.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  String _activeTab = 'cart';
  String? _itemToDeleteId;
  String? _itemToDeleteName;
  bool _showSuperCoinOtp = false;
  bool _showPaymentSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBrandDiscounts();
    });
  }

  void _fetchBrandDiscounts() {
    final cart = ref.read(cartProvider);
    if (cart != null && cart.items.isNotEmpty) {
      final brandsApi = ref.read(brandsApiProvider);
      ref.read(cartCheckoutProvider.notifier).fetchBrandDiscounts(cart.items, brandsApi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(cartCheckoutProvider);

    ref.listen(cartProvider, (prev, next) {
      if (next != null && next.items.isNotEmpty) {
        _fetchBrandDiscounts();
        // Reset in-memory order when the cart changes so a fresh order is
        // created on next pay (matches React's cart-signature reset effect).
        if (prev != null &&
            _cartSignature(prev.items) != _cartSignature(next.items)) {
          ref.read(paymentProvider.notifier).resetOrder();
        }
      }
    });

    final hasPopulatedCart = user != null && cart != null && cart.items.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          // Aurora background
          Positioned.fill(
            child: Image.asset('assets/images/ganeshbackdrop.png', fit: BoxFit.cover),
          ),
          // Main content
          Column(
            children: [
              if (hasPopulatedCart) _buildHeader(cart),
              Expanded(
                child: _buildBody(user, cart, checkout),
              ),
            ],
          ),
          // SuperCoins OTP modal — overlays the full screen like a real popup.
          if (_showSuperCoinOtp) _buildSuperCoinOtpModal(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Aurora Background (Section 2)
  // ─────────────────────────────────────────────
  Widget _buildAuroraBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF9747FF).withValues(alpha: 0.05),
            Colors.white,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Purple aurora blob
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 288,
              height: 288,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF9747FF).withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Blue aurora blob
          Positioned(
            top: 128,
            right: -64,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Grain texture overlay
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header (Section 4A)
  // ─────────────────────────────────────────────
  Widget _buildHeader(Cart? cart) {
    final itemCount = cart?.totalItems ?? 0;
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shopping Cart',
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'} in your cart',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(dynamic user, Cart? cart, CartCheckoutState checkout) {
    if (user == null) return _buildLoginPrompt();
    if (cart == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)));
    }
    if (cart.items.isEmpty) return _buildEmptyCart();
    return _buildCartContent(cart, checkout);
  }

  // ─────────────────────────────────────────────
  // Login Prompt
  // ─────────────────────────────────────────────
  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Please Login', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You need to be logged in to view your cart', style: GoogleFonts.poppins(color: const Color(0xFF6B7280))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Login to Continue'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Empty Cart (Section 4H)
  // ─────────────────────────────────────────────
  Widget _buildEmptyCart() {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9747FF).withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFF9747FF)),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add vouchers to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.go('/brands'),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9747FF), Color(0xFFB888FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9747FF).withValues(alpha: 0.25),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Start Shopping',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Cart Content
  // ─────────────────────────────────────────────
  Widget _buildCartContent(Cart cart, CartCheckoutState checkout) {
    return Column(
      children: [
        CartTabs(
          activeTab: _activeTab,
          onTabChange: (tab) => setState(() => _activeTab = tab),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Cart Items
                ...cart.items.map((item) => CartItemCard(
                      itemId: item.itemId,
                      brandName: item.brandName,
                      image: item.image,
                      quantity: item.quantity,
                      unitValue: item.unitValue,
                      lineTotal: item.lineTotal,
                      onQuantityChange: (itemId, qty) {
                        ref.read(cartProvider.notifier).updateQuantity(itemId, qty);
                      },
                      onRemove: (itemId) {
                        setState(() {
                          _itemToDeleteId = itemId;
                          _itemToDeleteName = item.brandName;
                        });
                      },
                    )),
                const SizedBox(height: 12),
                // Order Summary
                OrderSummarySection(
                  onSuperCoinTap: () async {
                    final ensured = await _ensureOrderBeforeSuperCoin();
                    if (ensured != null && mounted) {
                      setState(() => _showSuperCoinOtp = true);
                    }
                  },
                  onPaymentStart: () {
                    setState(() => _showPaymentSheet = true);
                  },
                  onPaymentComplete: () {
                    setState(() => _showPaymentSheet = false);
                  },
                ),
              ],
            ),
          ),
        ),
        // Dialogs
        if (_itemToDeleteId != null)
          DeleteConfirmDialog(
            brandName: _itemToDeleteName ?? '',
            onCancel: () => setState(() {
              _itemToDeleteId = null;
              _itemToDeleteName = null;
            }),
            onConfirm: () {
              ref.read(cartProvider.notifier).removeFromCart(_itemToDeleteId!);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$_itemToDeleteName removed from cart')),
              );
              setState(() {
                _itemToDeleteId = null;
                _itemToDeleteName = null;
              });
            },
          ),
        PaymentFlowSheet(isOpen: _showPaymentSheet, state: 'loading'),
      ],
    );
  }

  Widget _buildSuperCoinOtpModal() {
    final checkout = ref.read(cartCheckoutProvider);
    final superCoinState = ref.read(supercoinProvider);
    final user = ref.read(authProvider);
    final breakdown = ref.read(paymentBreakdownProvider);
    final paymentState = ref.read(paymentProvider);
    final orderNumber = checkout.superCoinOrderNumber ??
        paymentState.orderNumber ??
        _generateOrderNumber();

    return SuperCoinOTPModal(
      merchantWalletId: AppConfig.supercoinMerchantWalletId,
      orderNumber: orderNumber,
      displayName: (user?.name?.isNotEmpty == true) ? user!.name! : 'Gift360 Checkout',
      preloadedBalance: superCoinState.balance,
      maxRedeemable: breakdown.maxSuperCoinRedeemable,
      onAuthorized: (holdContext) {
        ref.read(cartCheckoutProvider.notifier).onSuperCoinAuthorized(holdContext, orderNumber);
        setState(() => _showSuperCoinOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SuperCoins applied successfully!')),
        );
      },
      onSwitchToCashback: () {
        setState(() => _showSuperCoinOtp = false);
        ref.read(cartCheckoutProvider.notifier).setRewardMode(RewardMode.cashbackWallet);
      },
      onClose: () => setState(() => _showSuperCoinOtp = false),
    );
  }

  /// Ensure a real (backend) order exists before starting the SuperCoin hold,
  /// matching React's openSuperCoinFlow → ensureOrder() so the hold's
  /// merchantReferenceId points at a real order (not a locally generated dummy).
  Future<String?> _ensureOrderBeforeSuperCoin() async {
    final user = ref.read(authProvider);
    final cart = ref.read(cartProvider);
    if (user == null || cart == null || cart.items.isEmpty) return null;

    final breakdown = ref.read(paymentBreakdownProvider);
    final checkout = ref.read(cartCheckoutProvider);

    // If we already have an authorized hold on a real order, reuse it.
    if (checkout.superCoinAuthorized && checkout.superCoinOrderNumber != null) {
      return checkout.superCoinOrderNumber;
    }

    final paymentNotifier = ref.read(paymentProvider.notifier);

    // If an order already exists for this cart signature, reuse it (React ensureOrder).
    final existing = ref.read(paymentProvider).orderNumber;
    if (existing != null) return existing;

    final orderItems = cart.items.map((item) => {
      'brandId': item.brandId,
      'quantity': item.quantity,
      'unitValue': item.unitValue,
      'lineTotal': item.lineTotal,
      'meta': jsonEncode({
        'brand_id': item.brandId,
        'brand_name': item.brandName,
        'image_url': item.image,
        'redeem_steps': <String>[],
      }),
    }).toList();

    final cartSignature = PaymentNotifier.cartSignatureFor(orderItems);

    final orderNumber = await paymentNotifier.createOrder(
      clientId: user.clientId,
      items: orderItems,
      totalAmount: cart.totalAmount,
      walletUsed: checkout.useWalletBalance,
      walletAmount: breakdown.walletDeduction,
      superCoinDeduction: breakdown.superCoinDeduction,
      superCoinAmount: checkout.superCoinHoldContext?.amount ?? 0,
      earnCashback: checkout.rewardMode != RewardMode.superCoins,
      cartSignature: cartSignature,
    );

    if (orderNumber == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start SuperCoins. Please try again.')),
        );
      }
      return null;
    }
    return orderNumber;
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    final yymmdd = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = DateTime.now().microsecondsSinceEpoch.toRadixString(16).toUpperCase();
    return 'ORD$yymmdd${random.substring(0, random.length.clamp(0, 12))}';
  }

  /// Cart checkout signature used to detect cart changes (matches React's
  /// getCartCheckoutSignature: sorted "itemId:quantity:unitValue" joined by "|").
  String _cartSignature(List<CartItem> items) {
    if (items.isEmpty) return '';
    final sigs = items
        .map((i) => '${i.itemId}:${i.quantity}:${i.unitValue}')
        .toList()
      ..sort();
    return sigs.join('|');
  }
}
