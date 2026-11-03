import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gift360/core/widgets/react_backdrop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/config/app_config.dart';
import 'package:gift360/core/utils/analytics.dart';
import 'package:gift360/core/widgets/app_bottom_nav.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/cart/presentation/widgets/cashback_wallet_section.dart';
import 'package:gift360/features/cart/presentation/widgets/payment_flow_sheet.dart';
import 'package:gift360/features/cart/presentation/widgets/rewards_toggle.dart';
import 'package:gift360/features/cart/presentation/widgets/supercoin_otp_modal.dart';
import 'package:gift360/features/cart/presentation/widgets/supercoin_status_card.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/home/presentation/providers/home_providers.dart';
import 'package:gift360/features/order/presentation/providers/order_provider.dart';
import 'package:gift360/features/payment/data/models/payment_method_fee.dart';
import 'package:gift360/features/payment/presentation/widgets/pay_using_sheet.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/supercoin/data/utils/supercoin_redemption.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_earn_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/wallet/data/utils/wallet_redemption.dart';

Map<String, dynamic> _parseOrderMeta(dynamic meta) {
  if (meta == null) return {};
  if (meta is String) {
    if (meta.isEmpty) return {};
    try {
      final decoded = jsonDecode(meta);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (_) {
      return {};
    }
  }
  if (meta is Map) return Map<String, dynamic>.from(meta);
  return {};
}

class _CheckoutItem {
  final String itemId;
  final String brandId;
  final String brandName;
  final int quantity;
  final double unitValue;
  final double lineTotal;
  final String? image;

  const _CheckoutItem({
    required this.itemId,
    required this.brandId,
    required this.brandName,
    required this.quantity,
    required this.unitValue,
    required this.lineTotal,
    this.image,
  });
}

class OrderCheckoutScreen extends ConsumerStatefulWidget {
  final String orderNumber;

  const OrderCheckoutScreen({super.key, required this.orderNumber});

  @override
  ConsumerState<OrderCheckoutScreen> createState() =>
      _OrderCheckoutScreenState();
}

class _OrderCheckoutScreenState extends ConsumerState<OrderCheckoutScreen> {
  // ── Order state ──
  List<_CheckoutItem> _orderItems = [];
  double _subtotal = 0;
  bool _initialWalletUsed = false;
  double _couponDiscount = 0;
  double _coinsRedeemed = 0;
  String? _previousSuperCoinTxnId;
  bool _orderLoading = true;
  bool _orderError = false;

  // ── Platform fee ──
  double _feePercent = 0.02;
  double _feeMax = 20;

  /// Selected cash payment method (UPI/DC/CC/NB) — drives the DB-backed fee.
  String _selectedPaymentMethod = 'UPI';

  // ── Brand discounts / multipliers ──
  final Map<String, double> _brandDiscountMap = {};
  final Map<String, double> _brandSupercoinMultiplierMap = {};
  final Set<String> _fetchedBrandIds = {};

  // ── Rewards / wallet / SuperCoin ──
  bool _useWalletBalance = false;
  int _rewardMode = 0; // 0 = cashbackWallet, 1 = superCoins
  bool _superCoinAuthorized = false;
  SuperCoinHoldContext? _superCoinHoldContext;
  bool _superCoinOTPModalOpen = false;
  bool _showSuperCoinRemoveDialog = false;
  int _selectedSCCoins = 0;
  bool _releasingPreviousHold = false;
  bool _seededWallet = false;
  int _countdownSeconds = 900;
  bool _countdownExpired = false;
  Timer? _countdownTimer;

  // ── Payment ──
  bool _isRetryingPayment = false;
  bool _paymentSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _loadPlatformFeeConfig();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    if (widget.orderNumber.isEmpty) return;
    setState(() {
      _orderLoading = true;
      _orderError = false;
    });
    try {
      final api = ref.read(orderApiProvider);
      final details = await api.fetchOrderDetails(widget.orderNumber);
      final rawItems = details['items'];
      final mapped = <_CheckoutItem>[];
      if (rawItems is List) {
        for (var idx = 0; idx < rawItems.length; idx++) {
          final it = rawItems[idx];
          if (it is! Map) continue;
          final meta = _parseOrderMeta(it['meta']);
          mapped.add(
            _CheckoutItem(
              itemId: (it['orderItemId'] ?? it['order_item_id'] ?? 'item-$idx')
                  .toString(),
              brandId: (it['brandId'] ?? meta['brand_id'] ?? '').toString(),
              brandName: (meta['brand_name'] ?? 'Voucher ${idx + 1}')
                  .toString(),
              quantity: (it['quantity'] is num
                  ? (it['quantity'] as num).toInt()
                  : 1),
              unitValue: (it['unitValue'] is num
                  ? (it['unitValue'] as num).toDouble()
                  : 0),
              lineTotal: (it['lineTotal'] is num
                  ? (it['lineTotal'] as num).toDouble()
                  : 0),
              image: _resolveImage(meta),
            ),
          );
        }
      }
      setState(() {
        _orderItems = mapped;
        _subtotal = (details['totalAmount'] is num
            ? (details['totalAmount'] as num).toDouble()
            : mapped.fold<double>(0, (s, i) => s + i.lineTotal));
        _initialWalletUsed = details['walletUsed'] == true;
        _couponDiscount = details['couponDiscount'] is num
            ? (details['couponDiscount'] as num).toDouble()
            : 0;
        _coinsRedeemed = details['coinsRedeemed'] is num
            ? (details['coinsRedeemed'] as num).toDouble()
            : 0;
        _previousSuperCoinTxnId = details['scMerchantTxnId']?.toString();
      });
      _fetchBrandDiscounts();
      // Seed the wallet toggle once the order loads (matches React's
      // seededWalletRef effect — re-applies the order's previous wallet choice
      // once the wallet balance has loaded).
      _seedWalletFromOrder();
    } catch (_) {
      setState(() => _orderError = true);
    } finally {
      setState(() => _orderLoading = false);
    }
  }

  String? _resolveImage(Map<String, dynamic> meta) {
    final imageUrl = meta['ImageUrl']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    final brandImageUrl = meta['brand_image_url']?.toString();
    if (brandImageUrl != null && brandImageUrl.isNotEmpty) return brandImageUrl;
    final fromImage = meta['image']?.toString();
    if (fromImage != null && fromImage.isNotEmpty) return fromImage;
    final brandId = (meta['BrandId'] ?? meta['brandId'] ?? meta['brand_id'])
        ?.toString();
    if (brandId != null && brandId.isNotEmpty) {
      return 'https://images.gift360.io/$brandId.png';
    }
    return null;
  }

  Future<void> _loadPlatformFeeConfig() async {
    try {
      final config = await ref.read(platformFeeConfigProvider.future);
      setState(() {
        _feePercent = (config['feePercent'] as num?)?.toDouble() ?? 0.02;
        _feeMax = (config['feeMax'] as num?)?.toDouble() ?? 20;
      });
    } catch (_) {}
  }

  /// Seed the wallet toggle once the order + wallet load (matches React's
  /// seededWalletRef effect that re-applies the previous wallet choice).
  Future<void> _seedWalletFromOrder() async {
    if (_seededWallet) return;
    try {
      await ref.read(walletBalanceProvider.future);
    } catch (_) {}
    if (mounted && !_seededWallet) {
      setState(() {
        _seededWallet = true;
        _useWalletBalance = _initialWalletUsed;
      });
    }
  }

  Future<void> _fetchBrandDiscounts() async {
    final uniqueBrandIds = _orderItems.map((i) => i.brandId).toSet();
    final unknown = uniqueBrandIds
        .where((id) => !_fetchedBrandIds.contains(id))
        .toList();
    if (unknown.isEmpty) return;

    final api = ref.read(brandsApiProvider);
    await Future.wait(
      unknown.map((brandId) async {
        _fetchedBrandIds.add(brandId);
        try {
          final Brand brand = await api.getBrandById(brandId);
          final discount = double.tryParse(brand.discount ?? '0') ?? 0;
          final multiplier = brand.supercoinMultiplier ?? 1.25;
          setState(() {
            _brandDiscountMap[brandId] = discount;
            _brandSupercoinMultiplierMap[brandId] = multiplier;
          });
        } catch (_) {
          setState(() {
            _brandDiscountMap[brandId] = 0;
            _brandSupercoinMultiplierMap[brandId] = 1.25;
          });
        }
      }),
    );
  }

  // ── Computations (mirror Cart exactly) ──
  double get _superCoinCapPercent =>
      ref.watch(superCoinConfigProvider).valueOrNull?.capPercent ?? 20;
  double get _walletBalance =>
      ref.read(walletBalanceProvider).value?.totalBalance ?? 0;
  double get _cashbackRedeemPercent =>
      ref.read(walletBalanceProvider).value?.cashbackRedeemPercent ?? 50.0;
  double get _maxRedeemAmount =>
      ref.read(walletBalanceProvider).value?.maxRedeemAmount ?? 100.0;

  Map<String, double> get _brandShares =>
      ref.read(superCoinBrandSharesProvider).valueOrNull ??
      const <String, double>{};

  bool _scExcluded(_CheckoutItem item) => isSuperCoinExcludedWithShares(
    _brandShares,
    brandId: item.brandId,
    brandName: item.brandName,
  );

  bool get _allItemsSuperCoinExcluded =>
      _orderItems.isNotEmpty && _orderItems.every(_scExcluded);

  int get _cartCashbackValueScale4 => _orderItems.fold(0, (sum, item) {
    final pct = _brandDiscountMap[item.brandId] ?? 0;
    return sum + walletItemCashbackScale4(item.lineTotal, pct);
  });

  double get _maxWalletUsage =>
      walletRedemptionCapPaise(
        _cartCashbackValueScale4,
        _cashbackRedeemPercent,
        _maxRedeemAmount,
      ) /
      100;

  double get _walletDeduction =>
      _useWalletBalance ? math.min(_walletBalance, _maxWalletUsage) : 0;

  bool get _discountsLoaded =>
      _orderItems.every((item) => _brandDiscountMap.containsKey(item.brandId));

  double get _maxSuperCoinRedeemable {
    if (!_discountsLoaded) return ref.read(supercoinProvider).balance;
    double totalCoinCap = 0;
    for (final item in _orderItems) {
      if (_scExcluded(item)) continue;
      final multiplier = _brandSupercoinMultiplierMap[item.brandId] ?? 1.25;
      final itemCapPercent =
          superCoinCapShare(_brandShares, item.brandId) ?? _superCoinCapPercent;
      final itemTotal = item.quantity * item.unitValue;
      totalCoinCap += supercoinItemCapCoins(
        itemTotal: itemTotal,
        capPercent: itemCapPercent,
        multiplier: multiplier,
      ).toDouble();
    }
    return totalCoinCap;
  }

  double get _effectiveSupercoinMultiplier {
    if (!_discountsLoaded) return 1.25;
    double totalRupeeCap = 0;
    double totalCoinCap = 0;
    for (final item in _orderItems) {
      if (_scExcluded(item)) continue;
      final multiplier = _brandSupercoinMultiplierMap[item.brandId] ?? 1.25;
      final itemCapPercent =
          superCoinCapShare(_brandShares, item.brandId) ?? _superCoinCapPercent;
      final itemTotal = item.quantity * item.unitValue;
      final itemRupeeCap = itemTotal * (itemCapPercent / 100);
      totalRupeeCap += itemRupeeCap;
      totalCoinCap += supercoinItemCapCoins(
        itemTotal: itemTotal,
        capPercent: itemCapPercent,
        multiplier: multiplier,
      ).toDouble();
    }
    return totalRupeeCap > 0 ? totalCoinCap / totalRupeeCap : 1.25;
  }

  double get _superCoinDeduction {
    final scState = ref.read(supercoinProvider);
    if (_allItemsSuperCoinExcluded ||
        !_superCoinAuthorized ||
        !scState.isEnrolled)
      return 0;
    final holdAmount = _superCoinHoldContext?.amount ?? scState.balance;
    return math.min(
          math.min(holdAmount, _maxSuperCoinRedeemable),
          scState.balance,
        ) /
        _effectiveSupercoinMultiplier;
  }

  List<PaymentMethodFee> get _paymentMethods =>
      ref.read(paymentMethodFeesProvider).valueOrNull ??
      const <PaymentMethodFee>[];

  PaymentMethodFee? get _activePaymentMethod =>
      activePaymentMethod(_paymentMethods, _selectedPaymentMethod);

  String _payMethodSubtext(String? code) {
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

  bool get _useMethodFee => _paymentMethods.isNotEmpty;

  /// Cash the customer pays before the platform fee (React `cashBeforeFee`).
  double get _cashBeforeFee => math.max(
    0,
    _subtotal - _couponDiscount - _walletDeduction - _superCoinDeduction,
  );

  double get _platformFee => _useMethodFee
      ? computeMethodFee(_activePaymentMethod, _cashBeforeFee)
      : (_superCoinDeduction > 0
            ? math.min(_subtotal * _feePercent, _feeMax)
            : 0);

  double get _finalPayable => _cashBeforeFee + _platformFee;

  double get _cashbackPercent {
    if (_orderItems.isEmpty) return 0;
    final totalLine = _orderItems.fold<double>(0, (s, i) => s + i.lineTotal);
    if (totalLine <= 0) return 0;
    return _orderItems.fold(0, (sum, item) {
      final disc = _brandDiscountMap[item.brandId] ?? 0;
      return sum + (item.lineTotal / totalLine) * disc;
    });
  }

  double get _cashbackAmount => _finalPayable * (_cashbackPercent / 100);

  Map<
    String,
    ({String brand, int quantity, double price, double total, double discount})
  >
  get _brandTotals {
    final map =
        <
          String,
          ({
            String brand,
            int quantity,
            double price,
            double total,
            double discount,
          })
        >{};
    for (final item in _orderItems) {
      final key = '${item.brandId}-${item.unitValue}';
      final discount = _brandDiscountMap[item.brandId] ?? 0;
      final existing = map[key];
      if (existing != null) {
        map[key] = (
          brand: existing.brand,
          quantity: existing.quantity + item.quantity,
          price: existing.price,
          total: existing.total + item.lineTotal,
          discount: existing.discount,
        );
      } else {
        map[key] = (
          brand: item.brandName,
          quantity: item.quantity,
          price: item.unitValue,
          total: item.lineTotal,
          discount: discount,
        );
      }
    }
    return map;
  }

  int get _maxSCCoins {
    final scState = ref.read(supercoinProvider);
    return math.max(
      0,
      math.min(scState.balance.toInt(), _maxSuperCoinRedeemable.toInt()),
    );
  }

  // ── SuperCoin hold helpers ──
  SuperCoinIdentity? get _superCoinIdentity {
    final normalized = normalizeMobileToE164(ref.read(authProvider)?.mobile);
    if (normalized == null) return null;
    return SuperCoinIdentity(identifier: normalized, type: 'MOBILE');
  }

  Future<void> _unholdSuperCoin() async {
    final identity = _superCoinIdentity;
    final merchantTransactionId =
        _superCoinHoldContext?.merchantTransactionId ?? _previousSuperCoinTxnId;
    if (merchantTransactionId == null || identity == null) return;
    try {
      final api = ref.read(supercoinApiProvider);
      await api.unhold({
        'identity': identity.toJson(),
        'merchantTransactionId': merchantTransactionId,
        'merchantWalletId':
            _superCoinHoldContext?.merchantWalletId ??
            AppConfig.supercoinMerchantWalletId,
      });
      AnalyticsService.trackSuperCoinRemoved(
        amount: _superCoinHoldContext?.amount ?? _coinsRedeemed,
      );
    } catch (_) {
    } finally {
      setState(() {
        _superCoinHoldContext = null;
        _superCoinAuthorized = false;
        _previousSuperCoinTxnId = null;
        _coinsRedeemed = 0;
        _countdownTimer?.cancel();
      });
      await SuperCoinOtpNotifier.clearHoldContext(widget.orderNumber);
      await SuperCoinOtpNotifier.clearActiveOrderNumber();
    }
  }

  void _requestSwitchToCashback() {
    if (_superCoinAuthorized || _previousSuperCoinTxnId != null) {
      setState(() => _showSuperCoinRemoveDialog = true);
      return;
    }
    setState(() => _rewardMode = 0);
  }

  Future<void> _openSuperCoinFlow() async {
    final identity = _superCoinIdentity;
    if (identity == null || widget.orderNumber.isEmpty) return;

    if (_previousSuperCoinTxnId != null) {
      setState(() => _releasingPreviousHold = true);
      try {
        final api = ref.read(supercoinApiProvider);
        await api.unhold({
          'identity': identity.toJson(),
          'merchantTransactionId': _previousSuperCoinTxnId,
          'merchantWalletId': AppConfig.supercoinMerchantWalletId,
        });
        setState(() {
          _previousSuperCoinTxnId = null;
          _superCoinAuthorized = false;
          _superCoinHoldContext = null;
          _countdownSeconds = 900;
          _countdownExpired = false;
        });
        await SuperCoinOtpNotifier.clearHoldContext(widget.orderNumber);
        await SuperCoinOtpNotifier.clearActiveOrderNumber();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not reset SuperCoins. Please try again before applying SuperCoins.',
              ),
            ),
          );
        }
        return;
      } finally {
        setState(() => _releasingPreviousHold = false);
      }
    }

    setState(() => _superCoinOTPModalOpen = true);
  }

  void _startCountdown(SuperCoinHoldContext ctx) {
    _countdownTimer?.cancel();
    int remaining = 900;
    if (ctx.transactionTime != null) {
      try {
        final startMs = DateTime.parse(
          ctx.transactionTime!,
        ).millisecondsSinceEpoch;
        final endMs = startMs + 15 * 60 * 1000;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .round()
            .clamp(0, 900);
      } catch (_) {}
    }
    setState(() {
      _countdownSeconds = remaining;
      _countdownExpired = remaining <= 0;
    });
    if (remaining <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _countdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
          _countdownExpired = true;
          _superCoinAuthorized = false;
          _superCoinHoldContext = null;
        });
        SuperCoinOtpNotifier.clearHoldContext(widget.orderNumber);
        SuperCoinOtpNotifier.clearActiveOrderNumber();
      } else {
        setState(() => _countdownSeconds = next);
      }
    });
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Pay orchestration ──
  Future<void> _handlePayNow() async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to place an order')),
      );
      context.push('/login');
      return;
    }

    // React OrderCheckout: the PayUsingField always opens the chooser — UPI
    // apps/QR → Juspay intent, cards/netbanking → Easebuzz (works even when the
    // DB fee table is unavailable).
    showPayUsingSheet(
      context: context,
      orderNumber: widget.orderNumber,
      cashAmount: _cashBeforeFee,
      methods: _paymentMethods,
      amountLabel: '\u20b9${_finalPayable.toStringAsFixed(2)}',
      onPaid: (_) => context.go('/orders'),
      onLeavePending: (_) => context.go('/orders'),
      onCardMethod: (code) => _startHostedPayment(methodCode: code),
      onFallbackToOtherMethods: () => _startHostedPayment(),
    );
  }

  Future<void> _startHostedPayment({String? methodCode}) async {
    try {
      setState(() {
        _isRetryingPayment = true;
        _paymentSheetOpen = true;
      });

      final walletUsed = _rewardMode == 0 && _useWalletBalance;

      // Persist SuperCoin hold for payment
      if (_superCoinAuthorized && _superCoinHoldContext != null) {
        await SuperCoinOtpNotifier.persistHoldContext(
          widget.orderNumber,
          _superCoinHoldContext!,
        );
        await SuperCoinOtpNotifier.persistActiveOrderNumber(widget.orderNumber);
      }

      // If switching to cashback with a stale hold, unhold first
      if (_rewardMode == 0 && _previousSuperCoinTxnId != null) {
        await _unholdSuperCoin();
      }

      final api = ref.read(orderApiProvider);
      final response = await api.retryPayment(
        widget.orderNumber,
        walletUsed: walletUsed,
        walletAmount: _walletDeduction,
        earnCashback: _rewardMode == 0,
        paymentMethod: _useMethodFee
            ? (methodCode ?? _selectedPaymentMethod)
            : null,
        // Hosted (Easebuzz) checkout must never offer UPI — it settles via
        // the Juspay intent flow (React's easebuzzPaymentModes filter).
        paymentModes: _useMethodFee
            ? easebuzzPaymentModes(_paymentMethods)
            : null,
      );

      final paymentUrl =
          response['payment_url'] ?? response['paymentUrl'] ?? response['data'];
      final status = response['status'];
      final statusOk = status == 1 || status == true || status == '1';

      if (!statusOk || paymentUrl == null || paymentUrl.toString().isEmpty) {
        throw Exception(
          response['message'] ??
              'Unable to initiate payment. Please try again.',
        );
      }

      AnalyticsService.trackEvent(
        'payment_initiated',
        params: {
          'value': _finalPayable,
          'currency': 'INR',
          'transaction_id': widget.orderNumber,
          'gateway': 'sabbpe',
        },
      );

      if (mounted) {
        setState(() => _paymentSheetOpen = false);
        context.push(
          '/payment-webview',
          extra: {
            'paymentUrl': paymentUrl.toString(),
            'orderNumber': widget.orderNumber,
          },
        );
      }
    } catch (e) {
      await _unholdSuperCoin();
      if (mounted) {
        setState(() => _paymentSheetOpen = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout Failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRetryingPayment = false);
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    // Rebuild when the DB-backed method fee table / brand shares arrive.
    ref.watch(paymentMethodFeesProvider);
    ref.watch(superCoinBrandSharesProvider);
    ref.watch(superCoinConfigProvider);

    if (!isAuthenticated || user == null) {
      return _buildLoginPrompt();
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: const ReactBackdropBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 16),
                  if (_orderLoading) _buildLoadingList(),
                  if (!_orderLoading && _orderError) _buildErrorState(),
                  if (!_orderLoading && !_orderError) ...[
                    _buildOrderDetailsTitle(),
                    const SizedBox(height: 12),
                    ..._orderItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCartItemCard(item),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildOrderSummaryCard(),
                  ],
                ],
              ),
            ),
          ),
          // Dialogs
          if (_showSuperCoinRemoveDialog) _buildSuperCoinRemoveDialog(),
          PaymentFlowSheet(isOpen: _paymentSheetOpen, state: 'loading'),
          if (_superCoinOTPModalOpen && _superCoinIdentity != null)
            SuperCoinOTPModal(
              merchantWalletId: AppConfig.supercoinMerchantWalletId,
              orderNumber: widget.orderNumber,
              displayName: user.name.isNotEmpty
                  ? user.name
                  : 'Gift360 Checkout',
              preloadedBalance: ref.watch(supercoinProvider).balance,
              maxRedeemable: _maxSuperCoinRedeemable,
              onAuthorized: (ctx) {
                setState(() {
                  _superCoinHoldContext = ctx;
                  _superCoinAuthorized = true;
                  _superCoinOTPModalOpen = false;
                });
                SuperCoinOtpNotifier.persistHoldContext(
                  widget.orderNumber,
                  ctx,
                );
                SuperCoinOtpNotifier.persistActiveOrderNumber(
                  widget.orderNumber,
                );
                _startCountdown(ctx);
                AnalyticsService.trackEvent(
                  'supercoin_applied',
                  params: {
                    'coins': ctx.amount,
                    'transaction_id': widget.orderNumber,
                  },
                );
              },
              onSwitchToCashback: () {
                setState(() => _superCoinOTPModalOpen = false);
                _requestSwitchToCashback();
              },
              onClose: () => setState(() => _superCoinOTPModalOpen = false),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: -1),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/my-orders');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: Color(0xFF1A1A1A),
            ),
            const SizedBox(width: 6),
            Text(
              'Back to Orders',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingList() {
    return Column(
      children: List.generate(
        2,
        (i) => Container(
          height: 112,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              "Can't view this order",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This order could not be loaded.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/my-orders');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B5CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text('Back to Orders', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
            children: [
              const TextSpan(text: 'Order '),
              TextSpan(
                text: widget.orderNumber,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemCard(_CheckoutItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: BrandImage(
              imageUrl: item.image,
              fit: BoxFit.contain,
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.brandName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${item.unitValue.toStringAsFixed(2)} each',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Read-only quantity stepper
                    Row(
                      children: [
                        _buildReadOnlyStepper(Icons.remove),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        _buildReadOnlyStepper(Icons.add),
                      ],
                    ),
                    Text(
                      '₹${item.lineTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9747FF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyStepper(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9747FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD7BDFF)),
      ),
      child: Icon(
        icon,
        size: 12,
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    ref.watch(walletBalanceProvider);
    final bt = _brandTotals;
    final earnKey = superCoinEarnKey(
      _orderItems.map((i) => MapEntry(i.brandId, i.lineTotal)).toList(),
      _cashBeforeFee,
    );
    final estimatedEarn = _rewardMode == 1
        ? (ref.watch(superCoinEarnEstimateProvider(earnKey)).valueOrNull ?? 0.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),

          // Brand totals rows
          ...bt.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.value.brand,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        if (e.value.discount > 0) ...[
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
                              '${e.value.discount.toStringAsFixed(0)}% Cashback',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${e.value.quantity} × ₹${e.value.price.toStringAsFixed(2)} = ₹${e.value.total.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),

          // Rewards toggle
          Center(
            child: RewardsToggle(
              selectedIndex: _rewardMode,
              onChanged: (index) {
                if (index == 0) {
                  _requestSwitchToCashback();
                } else {
                  setState(() {
                    _rewardMode = 1;
                    _useWalletBalance = false;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Cashback & Wallet section
          if (_rewardMode == 0)
            CashbackWalletSection(
              cashbackPercent: _cashbackPercent,
              cashbackAmount: _cashbackAmount,
              walletBalance: _walletBalance,
              maxWalletUsage: _maxWalletUsage,
              cashbackRedeemPercent: _cashbackRedeemPercent,
              walletDeduction: _walletDeduction,
              useWalletBalance: _useWalletBalance,
              onToggleWallet: () =>
                  setState(() => _useWalletBalance = !_useWalletBalance),
            ),

          // SuperCoins section
          if (_rewardMode == 1 && !_allItemsSuperCoinExcluded) ...[
            SuperCoinStatusCard(
              maxRedeemable: _maxSuperCoinRedeemable,
              estimatedEarn: estimatedEarn,
              hideToggle: true,
            ),
            const SizedBox(height: 12),
            if (!_superCoinAuthorized) ...[
              if (_maxSCCoins >= 1) _buildCoinsSlider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed:
                      _releasingPreviousHold ||
                          ref.watch(supercoinProvider).balance <= 0 ||
                          _maxSCCoins < 1 ||
                          _selectedSCCoins < 1
                      ? null
                      : _openSuperCoinFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9747FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _releasingPreviousHold
                        ? 'Releasing previous hold...'
                        : 'Apply SuperCoins',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else
              _buildActiveSuperCoinSection(),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),

          // Subtotal
          _buildSummaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),

          if (_walletDeduction > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Wallet Points Used',
              '-₹${_walletDeduction.toStringAsFixed(2)}',
              valueColor: const Color(0xFF10B981),
            ),
          ],

          if (_superCoinAuthorized && _superCoinHoldContext != null) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'SuperCoins Redeemed',
              '${_superCoinHoldContext!.amount.toInt()} SC',
              valueColor: const Color(0xFF10B981),
            ),
          ],

          if (_couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Coupon Discount',
              '-₹${_couponDiscount.toStringAsFixed(2)}',
            ),
          ],

          if (_platformFee > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Platform Fee${_activePaymentMethod != null ? ' \u00b7 ${_activePaymentMethod!.label}' : ''}',
              '₹${_platformFee.toStringAsFixed(2)}',
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // Pay Now total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pay Now',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              Text(
                '₹${_finalPayable.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9747FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // PayUsingField (React): tap opens the "Pay using" chooser.
          GestureDetector(
            onTap: _isRetryingPayment || _orderLoading || _orderItems.isEmpty
                ? null
                : _handlePayNow,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: _isRetryingPayment
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                      ),
                color: _isRetryingPayment ? const Color(0xFFD1D5DB) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isRetryingPayment
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
                          _activePaymentMethod?.label ?? 'UPI',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          _payMethodSubtext(_activePaymentMethod?.code),
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
                  _isRetryingPayment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Pay \u20b9${_finalPayable.toStringAsFixed(2)}',
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

  Widget _buildCoinsSlider() {
    final maxSC = _maxSCCoins;
    final current = _selectedSCCoins.clamp(1, maxSC);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF9747FF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9747FF).withValues(alpha: 0.25),
        ),
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
                '$current SC',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          Slider(
            value: current.toDouble(),
            min: 1,
            max: maxSC.toDouble(),
            divisions: maxSC > 1 ? maxSC - 1 : 1,
            activeColor: const Color(0xFF9747FF),
            inactiveColor: const Color(0xFF9747FF).withValues(alpha: 0.2),
            onChanged: (v) => setState(() => _selectedSCCoins = v.toInt()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Save ₹${(current / _effectiveSupercoinMultiplier).toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              Text(
                'Max $maxSC SC · ${_superCoinCapPercent.toStringAsFixed(2)}% of voucher value',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSuperCoinSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF9747FF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF9747FF).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'SuperCoins active',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Image.asset(
                    'assets/images/SuperCOin-removebg-preview.png',
                    width: 20,
                    height: 20,
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  await _unholdSuperCoin();
                  setState(() => _rewardMode = 0);
                },
                child: Text(
                  'Remove',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7C3AED),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_countdownExpired &&
            _superCoinHoldContext?.transactionTime != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Color(0xFF7C3AED)),
                const SizedBox(width: 6),
                Text(
                  'Use your SuperCoins within ${_formatCountdown(_countdownSeconds)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_countdownExpired) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SuperCoin hold expired. Please apply again.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ),
        ],
        if (_superCoinDeduction > 0) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Saving ₹${_superCoinDeduction.toStringAsFixed(2)} on this order',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildSuperCoinRemoveDialog() {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Remove your SuperCoins from this purchase?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your reserved SuperCoins will not be used for this payment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showSuperCoinRemoveDialog = false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      setState(() => _showSuperCoinRemoveDialog = false);
                      await _unholdSuperCoin();
                      setState(() => _rewardMode = 0);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Remove', style: GoogleFonts.poppins()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: const ReactBackdropBackground()),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: const Color(0xFF1A1A2E),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 40,
                      color: Color(0xFFFCD34D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please Login',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7B5CFF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to complete your order',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFCD34D),
                      foregroundColor: const Color(0xFF78350F),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
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
