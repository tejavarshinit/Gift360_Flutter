import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/core/navigation/app_back_navigation_scope.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/cart/presentation/widgets/supercoin_otp_modal.dart';
import 'package:gift360/features/cart/presentation/widgets/supercoin_redeemed_modal.dart';
import 'package:gift360/features/home/presentation/providers/home_providers.dart';
import 'package:gift360/features/payment/data/models/payment_method_fee.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/presentation/widgets/add_to_cart_success_modal.dart';
import 'package:gift360/features/payment/presentation/widgets/pay_using_sheet.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/data/utils/supercoin_redemption.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_earn_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/wallet/data/utils/wallet_redemption.dart';

class PaymentDetailsSheet extends ConsumerStatefulWidget {
  final Brand? brand;
  final bool loading;
  final bool processing;
  final String? error;
  final VoidCallback onClose;
  final void Function(Brand brand, double amount, int quantity) onAddToCart;
  final void Function(
    Brand brand,
    double amount,
    int quantity,
    String? paymentMethod,
  )
  onPay;

  const PaymentDetailsSheet({
    super.key,
    required this.brand,
    this.loading = false,
    this.processing = false,
    this.error,
    required this.onClose,
    required this.onAddToCart,
    required this.onPay,
  });

  @override
  ConsumerState<PaymentDetailsSheet> createState() =>
      _PaymentDetailsSheetState();
}

class _PaymentDetailsSheetState extends ConsumerState<PaymentDetailsSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedAmount;
  final TextEditingController _amountController = TextEditingController();
  bool _amountUserEdited = false;
  int _quantity = 1;
  String _infoTab = '';
  String _selectedPaymentMethod = 'UPI';
  Brand? _detailedBrand;

  // Rewards choice at buy time: 0 = cashback/wallet, 1 = SuperCoins
  // (mirrors React PaymentDetailsSheet's payMode). The pay UI is staged:
  // Buy Now -> pay panel (choose mode) -> Pay -> method modal (UPI etc) -> pay.
  int _payMode = 0;
  bool _modeChosen = false;
  bool _payPanelOpen = false;
  bool _useWalletBalance = false;
  bool _superCoinAuthorized = false;
  SuperCoinHoldContext? _superCoinHoldContext;
  double _selectedSCCoins = 0;
  bool _scPreviewOff = false;
  String _orderNumber = '';
  String _orderSignature = '';
  bool _isPaying = false;
  bool _isClosing = false;
  final Object _backHandlerKey = Object();
  AppBackNavigationController? _backNavigationController;

  /// Post-OTP "Your SuperCoins are burned — continue payment in 3.2.1" bridge
  /// and the 15-minute hold countdown (mirrors React PaymentDetailsSheet).
  bool _showRedeemed = false;
  int _scCountdownSeconds = 900;
  bool _scCountdownExpired = false;
  Timer? _scCountdownTimer;
  Brand? _pendingBrand;

  /// Live per-brand multiplier from `/brands/{id}` when the caller's Brand
  /// object didn't carry `supercoinMultiplier` (React fetches it in-sheet).
  double? _liveBrandMultiplier;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    hideGlobalSupportChat();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
    _ensureDefaultAmount(widget.brand);
    _loadDetailedBrand(widget.brand);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppBackNavigationScope.maybeControllerOf(context);
    if (identical(controller, _backNavigationController)) return;

    _backNavigationController?.unregister(_backHandlerKey);
    _backNavigationController = controller;
    if (controller != null) {
      final router = GoRouter.of(context);
      final routePath = router.routerDelegate.currentConfiguration.uri.path;
      controller.register(
        _backHandlerKey,
        _close,
        isActive: () =>
            router.routerDelegate.currentConfiguration.uri.path == routePath,
      );
    }
  }

  @override
  void didUpdateWidget(covariant PaymentDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.brand?.brandId;
    final newId = widget.brand?.brandId;
    if (oldId != newId) {
      _detailedBrand = null;
      _liveBrandMultiplier = null;
      _selectedAmount = null;
      _amountUserEdited = false;
      _amountController.clear();
      _ensureDefaultAmount(widget.brand);
      _loadDetailedBrand(widget.brand);
    }
  }

  void _setAmount(String? value) {
    _selectedAmount = value;
    final text = value ?? '';
    if (_amountController.text != text) {
      _amountController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _ensureDefaultAmount(Brand? brand, {bool force = false}) {
    if (brand == null) return;
    if (_amountUserEdited) return;
    if (!force && (_selectedAmount?.isNotEmpty ?? false)) return;
    final denominations = _parseDenominations(
      brand.denominationList ?? brand.denomination,
    );
    final isFixed = (brand.brandType ?? '').toLowerCase() == 'fixed';
    final defaultAmount = isFixed && denominations.isNotEmpty
        ? denominations.first
        : brand.effectiveStartingPrice;
    if (defaultAmount <= 0) return;
    final value = defaultAmount == defaultAmount.roundToDouble()
        ? defaultAmount.toStringAsFixed(0)
        : defaultAmount.toString();
    _setAmount(value);
  }

  Future<void> _loadDetailedBrand(Brand? brand) async {
    final brandId = brand?.brandId ?? '';
    if (brandId.isEmpty) return;
    try {
      final fresh = await ref.read(brandsApiProvider).getBrandById(brandId);
      if (!mounted || widget.brand?.brandId != brandId) return;
      setState(() {
        _detailedBrand = fresh;
        _liveBrandMultiplier = fresh.supercoinMultiplier;
        _ensureDefaultAmount(fresh, force: true);
      });
    } catch (_) {
      // The list response remains a usable fallback if details are unavailable.
    }
  }

  @override
  void dispose() {
    _backNavigationController?.unregister(_backHandlerKey);
    showGlobalSupportChat();
    _scCountdownTimer?.cancel();
    _amountController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    _unholdSuperCoinIfNeeded();
    _slideController.reverse().then((_) => widget.onClose());
  }

  SuperCoinIdentity? get _superCoinIdentity {
    final user = ref.read(authProvider);
    final normalized = normalizeMobileToE164(user?.mobile);
    if (normalized == null || normalized.isEmpty) return null;
    return SuperCoinIdentity(identifier: normalized, type: 'MOBILE');
  }

  void _unholdSuperCoinIfNeeded() {
    final ctx = _superCoinHoldContext;
    final identity = _superCoinIdentity;
    _superCoinHoldContext = null;
    _superCoinAuthorized = false;
    _scCountdownTimer?.cancel();
    _scCountdownTimer = null;
    _scCountdownExpired = false;
    _scCountdownSeconds = 900;
    if (ctx == null || identity == null) return;
    ref
        .read(supercoinApiProvider)
        .unhold({
          'identity': identity.toJson(),
          'merchantTransactionId': ctx.merchantTransactionId,
          'merchantWalletId': ctx.merchantWalletId,
        })
        .then((_) {}, onError: (_) {});
  }

  void _invalidateOrder() {
    _orderNumber = '';
    _orderSignature = '';
    _unholdSuperCoinIfNeeded();
  }

  void _switchPayMode(int mode) {
    if (mode == _payMode) return;
    if (mode == 0) _unholdSuperCoinIfNeeded();
    setState(() {
      _payMode = mode;
      if (mode == 1) _useWalletBalance = false;
      _scPreviewOff = false;
    });
  }

  /// Prices the order exactly like Cart/React: wallet cap from cashback value,
  /// SuperCoin cap from the DB share/cap × multiplier, DB method fee on cash.
  _SheetPricing _pricing(Brand brand, double total, double discountPercent) {
    final walletData = ref.read(walletBalanceProvider).value;
    final scState = ref.read(supercoinProvider);
    final configAsync = ref.read(superCoinConfigProvider);
    final config = configAsync.hasValue && !configAsync.hasError
        ? configAsync.valueOrNull
        : null;
    final shares =
        ref.read(superCoinBrandSharesProvider).valueOrNull ??
        const <String, double>{};
    final brandId = brand.brandId ?? '';
    final brandName = brand.brandName ?? '';
    final capPercent = config?.capPercent ?? 20.0;
    // Per-brand multiplier (coins per ₹1) from the DB `/brands/{id}` payload,
    // exactly like React; 1.25 only when the backend has no value.
    final brandMultiplier =
        _liveBrandMultiplier ?? brand.supercoinMultiplier ?? 0;
    final multiplier = brandMultiplier > 0 ? brandMultiplier : 1.25;

    final excluded = isSuperCoinExcludedWithShares(
      shares,
      brandId: brandId,
      brandName: brandName,
    );
    final share = superCoinCapShare(shares, brandId);
    // Brand-level eligibility (matches React): the Cash+SuperCoins mode is
    // shown for every eligible brand, even before enrollment / with 0 coins —
    // the mode panel then explains how to register or that there's nothing to
    // redeem. Coin availability is clamped separately below.
    final scEligible = !excluded;
    final capSC = (!excluded && total > 0)
        ? supercoinItemCapCoins(
            itemTotal: total,
            capPercent: share ?? capPercent,
            multiplier: multiplier,
          ).toDouble()
        : 0.0;
    // React's `maxSCCoins = min(balance, maxSuperCoinRedeemable)`.
    final maxSC = math.min(scState.balance, capSC);
    final hold = _superCoinHoldContext;
    final authorizedSC = (_superCoinAuthorized && hold != null)
        ? math.min(math.min(hold.amount, maxSC), scState.balance) / multiplier
        : 0.0;
    final clampedSelected = maxSC < 1
        ? 0.0
        : (_selectedSCCoins < 1 ? maxSC : math.min(_selectedSCCoins, maxSC));
    final previewSC =
        (_payMode == 1 &&
            !_superCoinAuthorized &&
            !_scPreviewOff &&
            scState.isEnrolled &&
            scEligible &&
            clampedSelected >= 1)
        ? math.min(clampedSelected / multiplier, total)
        : 0.0;
    final scDeduction = authorizedSC > 0 ? authorizedSC : previewSC;

    final cashbackRedeemPercent = walletData?.cashbackRedeemPercent ?? 50.0;
    final maxRedeemAmount = walletData?.maxRedeemAmount ?? 100.0;
    final maxWalletUsage =
        walletRedemptionCapPaise(
          walletItemCashbackScale4(total, discountPercent),
          cashbackRedeemPercent,
          maxRedeemAmount,
        ) /
        100;
    final walletBalance = (walletData?.totalBalance ?? 0).toDouble();
    final wallet = (_payMode == 0 && _useWalletBalance)
        ? math.min(walletBalance, maxWalletUsage)
        : 0.0;

    final cash = math.max(0.0, total - wallet - scDeduction);

    final methods =
        ref.read(paymentMethodFeesProvider).valueOrNull ??
        const <PaymentMethodFee>[];
    final active = activePaymentMethod(methods, _selectedPaymentMethod);
    final useMethodFee = methods.isNotEmpty;
    final feeConfig = ref.read(platformFeeConfigProvider).valueOrNull;
    final feePctKey = _payMode == 1 ? 'feePercent' : 'feePercentCash';
    final feeMaxKey = _payMode == 1 ? 'feeMax' : 'feeMaxCash';
    final feePct = (feeConfig?[feePctKey] as num?)?.toDouble() ?? 0.02;
    final feeMax = (feeConfig?[feeMaxKey] as num?)?.toDouble() ?? 20.0;
    final roundedLegacy = ((total * feePct) * 100).roundToDouble() / 100;
    final legacyFee = roundedLegacy < feeMax ? roundedLegacy : feeMax;
    final fee = total > 0
        ? (useMethodFee ? computeMethodFee(active, cash) : legacyFee)
        : 0.0;

    return _SheetPricing(
      total: total,
      wallet: wallet,
      scDeduction: scDeduction,
      cash: cash,
      fee: fee,
      totalPay: cash + fee,
      maxSC: maxSC,
      selectedSC: clampedSelected,
      scEligible: scEligible,
      multiplier: multiplier,
      maxWalletUsage: maxWalletUsage,
      walletBalance: walletBalance,
      method: useMethodFee ? active : null,
    );
  }

  Future<String> _ensureOrder(Brand brand, double amount, int quantity) async {
    final user = ref.read(authProvider);
    if (user == null) throw 'Please login to continue payment.';
    final total = amount * quantity;
    final pricing = _pricing(
      brand,
      total,
      double.tryParse(brand.discount ?? '0') ?? 0,
    );
    final signature =
        '${brand.brandId}|$amount|$quantity|w${_useWalletBalance ? 1 : 0}|m$_payMode';
    if (_orderNumber.isNotEmpty && _orderSignature == signature) {
      return _orderNumber;
    }
    final orderNumber = await ref
        .read(paymentProvider.notifier)
        .createOrder(
          clientId: user.clientId,
          items: [
            {
              'brandId': brand.brandId ?? '',
              'quantity': quantity,
              'unitValue': amount,
              'lineTotal': total,
              'meta': jsonEncode({
                'brand_id': brand.brandId,
                'brand_name': brand.brandName,
                'image_url': brand.resolvedImageUrl,
                'redeem_steps': <String>[],
              }),
            },
          ],
          totalAmount: total,
          walletUsed: _payMode == 0 && _useWalletBalance,
          walletAmount: pricing.wallet,
          earnCashback: _payMode == 0,
          cartSignature: signature,
        );
    if (orderNumber == null) {
      throw ref.read(paymentProvider).error ?? 'Failed to create order';
    }
    _orderNumber = orderNumber;
    _orderSignature = signature;
    return orderNumber;
  }

  Future<void> _openSuperCoinFlow(
    Brand brand,
    double amount,
    int quantity,
  ) async {
    final user = ref.read(authProvider);
    final identity = _superCoinIdentity;
    if (user == null || identity == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SuperCoins need a verified mobile number on your profile.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _isPaying = true);
    try {
      final orderNumber = await _ensureOrder(brand, amount, quantity);
      if (!mounted) return;
      final pricing = _pricing(
        brand,
        amount * quantity,
        double.tryParse(brand.discount ?? '0') ?? 0,
      );
      setState(() {
        _isPaying = false;
        _pendingBrand = brand;
      });
      final displayName = user.name.isNotEmpty ? user.name : 'Gift360 Checkout';
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        builder: (dialogContext) => SuperCoinOTPModal(
          merchantWalletId: AppConfig.supercoinMerchantWalletId,
          orderNumber: orderNumber,
          displayName: displayName,
          preloadedBalance: ref.read(supercoinProvider).balance,
          maxRedeemable: pricing.maxSC,
          initialCoinAmount: pricing.selectedSC,
          onAuthorized: (ctx) {
            Navigator.of(dialogContext).pop();
            setState(() {
              _superCoinHoldContext = ctx;
              _superCoinAuthorized = true;
              _showRedeemed = true;
            });
            _startScCountdown(ctx);
          },
          onSwitchToCashback: () {
            Navigator.of(dialogContext).pop();
            _switchPayMode(0);
          },
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SuperCoins unavailable right now: $e')),
      );
    }
  }

  /// 15-minute hold countdown shown after the OTP ("Pay within 14:59"). The
  /// hold is dead server-side on expiry, so drop the local authorization — the
  /// same terminal state React uses.
  void _startScCountdown(SuperCoinHoldContext holdContext) {
    _scCountdownTimer?.cancel();
    int remaining = 900;

    if (holdContext.transactionTime != null) {
      try {
        final startMs = DateTime.parse(
          holdContext.transactionTime!,
        ).millisecondsSinceEpoch;
        final endMs = startMs + 15 * 60 * 1000;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .round()
            .clamp(0, 900);
      } catch (_) {
        if (holdContext.stampExpiry != null) {
          remaining =
              ((holdContext.stampExpiry! -
                          DateTime.now().millisecondsSinceEpoch) /
                      1000)
                  .round()
                  .clamp(0, 900);
        }
      }
    }

    setState(() {
      _scCountdownSeconds = remaining;
      _scCountdownExpired = remaining <= 0;
    });
    if (remaining <= 0) {
      _expireScHold();
      return;
    }

    _scCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = _scCountdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        _expireScHold();
      } else if (mounted) {
        setState(() => _scCountdownSeconds = next);
      }
    });
  }

  void _expireScHold() {
    if (!mounted) return;
    _scCountdownTimer?.cancel();
    _scCountdownTimer = null;
    setState(() {
      _scCountdownSeconds = 0;
      _scCountdownExpired = true;
      _superCoinAuthorized = false;
      _superCoinHoldContext = null;
    });
  }

  /// Redeemed bridge finished (3·2·1) — continue straight into payment, like
  /// React's `SuperCoinRedeemedModal` `onContinue` → `doPay()`.
  void _onRedeemedContinue() {
    final brand = _pendingBrand;
    setState(() => _showRedeemed = false);
    if (brand == null) return;
    _confirmPayFromPanel(brand);
  }

  Future<void> _handlePayPressed(
    Brand brand,
    double amount,
    int quantity,
  ) async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue payment')),
      );
      context.push('/login');
      return;
    }
    final total = amount * quantity;
    final pricing = _pricing(
      brand,
      total,
      double.tryParse(brand.discount ?? '0') ?? 0,
    );
    if (_payMode == 1 && !_superCoinAuthorized && pricing.scDeduction > 0) {
      final use = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use SuperCoins?'),
          content: Text(
            'Apply ${pricing.selectedSC.toStringAsFixed(0)} SuperCoins and pay the rest by cash?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (use == true) {
        await _openSuperCoinFlow(brand, amount, quantity);
        return;
      }
      // Paying without coins: drop the previewed deduction so the total shown
      // matches what the backend will charge.
      setState(() => _scPreviewOff = true);
    }
    await _doPay(brand, amount, quantity);
  }

  /// Hosted (Easebuzz/SabbPe) checkout: initiate + redirect. UPI is never
  /// offered here — the payload carries every mode EXCEPT UPI.
  Future<void> _startHostedPayment(String orderNumber) async {
    final methods =
        ref.read(paymentMethodFeesProvider).valueOrNull ??
        const <PaymentMethodFee>[];
    final response = await ref
        .read(paymentProvider.notifier)
        .initiateBackendPayment(
          paymentMethod: methods.isEmpty ? null : _selectedPaymentMethod,
          paymentModes: methods.isEmpty ? null : easebuzzPaymentModes(methods),
        );
    if (response == null) {
      throw ref.read(paymentProvider).error ?? 'Payment initiation failed';
    }
    final paymentUrl =
        response['payment_url'] ?? response['paymentUrl'] ?? response['data'];
    if (paymentUrl == null || paymentUrl.toString().isEmpty) {
      throw 'Payment URL not received from gateway';
    }
    final router = GoRouter.of(context);
    final extra = <String, dynamic>{
      'paymentUrl': paymentUrl.toString(),
      'orderNumber': orderNumber,
    };
    // The backend redeems the hold against this order on success.
    _superCoinHoldContext = null;
    _superCoinAuthorized = false;
    setState(() => _isPaying = false);
    widget.onClose();
    router.push('/payment-webview', extra: extra);
  }

  /// Juspay UPI-intent flow for an already validated order (React:
  /// `setUpiIntentOrder(orderNumber)`).
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

  /// "Pay using" chooser (React `PayUsingSheet`): UPI apps + QR go through the
  /// Juspay intent flow; NetBanking / Debit / Credit go through Easebuzz.
  void _showPayUsing(
    String orderNumber,
    _SheetPricing pricing,
    List<PaymentMethodFee> methods,
  ) {
    final router = GoRouter.of(context);
    showPayUsingSheet(
      context: context,
      orderNumber: orderNumber,
      cashAmount: pricing.cash,
      methods: methods,
      amountLabel: '\u20b9${pricing.totalPay.toStringAsFixed(2)}',
      onPaid: (_) {
        widget.onClose();
        router.go('/orders');
      },
      onLeavePending: (_) {
        widget.onClose();
        router.go('/orders');
      },
      onCardMethod: (code) {
        setState(() => _selectedPaymentMethod = code);
        _startHostedPayment(orderNumber).catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Checkout Failed: $e')));
          }
        });
      },
      onFallbackToOtherMethods: () {
        final fallback = methods
            .where((m) => !isUpiPaymentMethod(m.code))
            .toList();
        if (fallback.isNotEmpty) {
          setState(() => _selectedPaymentMethod = fallback.first.code);
        }
        _startHostedPayment(orderNumber).catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Checkout Failed: $e')));
          }
        });
      },
    );
  }

  Future<void> _doPay(Brand brand, double amount, int quantity) async {
    final total = amount * quantity;
    setState(() => _isPaying = true);
    try {
      final orderNumber = await _ensureOrder(brand, amount, quantity);
      final pricing = _pricing(
        brand,
        total,
        double.tryParse(brand.discount ?? '0') ?? 0,
      );
      final valid = await ref
          .read(paymentProvider.notifier)
          .validateOrder(
            cartTotal: total,
            walletAmount: pricing.wallet,
            walletUsed: _payMode == 0 && _useWalletBalance,
          );
      if (!valid) {
        throw ref.read(paymentProvider).error ?? 'Order validation failed';
      }
      final methods =
          ref.read(paymentMethodFeesProvider).valueOrNull ??
          const <PaymentMethodFee>[];
      // ONE Pay button: open the "Pay using" chooser (UPI apps/QR → Juspay,
      // cards/NB → Easebuzz). It still works when the DB fee table is
      // unavailable (fees show "at checkout"), exactly like React.
      setState(() => _isPaying = false);
      _showPayUsing(orderNumber, pricing, methods);
      return;
    } catch (e) {
      _unholdSuperCoinIfNeeded();
      if (!mounted) return;
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Checkout Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.brand;

    if (widget.loading || brand == null) {
      final topPadding = MediaQuery.of(context).padding.top;
      final navBarHeight = topPadding + 56;
      return GestureDetector(
        onTap: _close,
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {},
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height - navBarHeight,
                margin: EdgeInsets.only(top: navBarHeight),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 34,
                                color: Color(0xFFEF4444),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475467),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _close,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C5CE7),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                            SizedBox(height: 12),
                            Text(
                              'Loading payment details...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isFixed = (brand.brandType ?? '').toLowerCase() == 'fixed';
    final minPrice = brand.effectiveStartingPrice;
    final maxPrice = brand.maxPrice ?? 0;
    final denominations = _parseDenominations(
      brand.denominationList ?? brand.denomination,
    );

    final amount = double.tryParse(_selectedAmount ?? '') ?? 0;
    final total = amount * _quantity;
    final discount = double.tryParse(brand.discount ?? '0') ?? 0;
    final cashback = total > 0 ? (total * discount / 100).toInt() : 0;

    final topPadding = MediaQuery.of(context).padding.top;
    final navBarHeight = topPadding + 56;

    return Stack(
      children: [
        GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black54,
            child: GestureDetector(
              onTap: () {},
              child: SlideTransition(
                position: _slideAnimation,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: MediaQuery.of(context).size.height - navBarHeight,
                    margin: EdgeInsets.only(top: navBarHeight),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F5F9),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(50),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 100,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _close,
                                child: const Icon(
                                  Icons.chevron_left,
                                  size: 24,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Payment Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              children: [
                                _buildBrandCard(brand),
                                const SizedBox(height: 16),
                                _buildAmountSelection(
                                  brand,
                                  isFixed,
                                  denominations,
                                  minPrice,
                                  maxPrice,
                                ),
                                if (cashback > 0 && _payMode == 0) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.currency_rupee,
                                          size: 16,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '+ ₹$cashback cashback',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          width: 60,
                                          height: 2,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(
                                              1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _buildQuantitySection(amount),
                                const SizedBox(height: 16),
                                _buildInfoTabs(_brandWithFetchedDetails(brand)),
                              ],
                            ),
                          ),
                        ),
                        _buildBottomBar(brand, total, cashback),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_payPanelOpen) _buildPayPanel(brand),
        if (_showRedeemed)
          SuperCoinRedeemedModal(
            open: _showRedeemed,
            onContinue: _onRedeemedContinue,
          ),
      ],
    );
  }

  Widget _buildBrandCard(Brand brand) {
    final discount = brand.discount ?? '';
    final imageUrl = brand.resolvedImageUrl;
    return SizedBox(
      width: 342,
      height: 86,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: imageUrl != null
                      ? BrandImage(imageUrl: imageUrl, fit: BoxFit.contain)
                      : const Icon(Icons.store, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 58),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand.brandName ?? 'Brand',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'E-Gift Cards',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 20,
                          constraints: const BoxConstraints(minWidth: 145),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF78DEFF), Color(0xFF488599)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x5578DEFF),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            brand.category ?? 'E-Commerce & Shopping',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (discount.isNotEmpty)
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  width: 61,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      topLeft: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Cashback\n$discount%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSelection(
    Brand brand,
    bool isFixed,
    List<double> denominations,
    double minPrice,
    double maxPrice,
  ) {
    final discountPercent = double.tryParse(brand.discount ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Amount',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          if (minPrice > 0 && minPrice == maxPrice) ...[
            const SizedBox(height: 4),
            _denomPill(minPrice, active: true, onTap: null),
            const SizedBox(height: 4),
            _cashbackRow((minPrice * discountPercent / 100).round()),
          ] else if (isFixed) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: denominations.map((d) {
                final isSelected = _selectedAmount == d.toInt().toString();
                return GestureDetector(
                  onTap: () => setState(() {
                    _amountUserEdited = true;
                    _setAmount(d.toInt().toString());
                    _invalidateOrder();
                  }),
                  child: AnimatedScale(
                    scale: isSelected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(minWidth: 0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF9747FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF9747FF)
                              : const Color(0xFFDAD5FF),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '₹${d.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF3E3E3E),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            if (_selectedAmount != null)
              _cashbackRow(
                ((double.tryParse(_selectedAmount!) ?? 0) *
                        discountPercent /
                        100)
                    .round(),
              ),
          ] else ...[
            _buildVariableAmountInput(minPrice, maxPrice, discountPercent),
          ],
        ],
      ),
    );
  }

  Widget _cashbackRow(int cashback) {
    if (cashback <= 0 || _payMode != 0) return const SizedBox.shrink();
    return Row(
      children: [
        Text(
          '+₹$cashback cashback',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _denomPill(
    double denom, {
    required bool active,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF9747FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF9747FF) : const Color(0xFFDAD5FF),
            width: 2,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Text(
          '₹${denom.toInt()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF3E3E3E),
          ),
        ),
      ),
    );
  }

  /// Variable amount input matching the React PaymentDetailsSheet:
  /// hint text "Enter amount between ₹min - ₹max", a text input with
  /// purple focus border, and a live "+₹n cashback" preview below.
  Widget _buildVariableAmountInput(
    double min,
    double max,
    double discountPercent,
  ) {
    final amount = double.tryParse(_selectedAmount ?? '') ?? 0;
    final cashback = (amount * discountPercent / 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint row with purple dot
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF9747FF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Enter amount between ₹${min.toInt()} - ₹${max.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Text input field
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final raw = value.replaceAll(RegExp(r'[^0-9]'), '');
            setState(() {
              _amountUserEdited = true;
              _selectedAmount = raw.isEmpty ? null : raw;
              if (raw != value) _setAmount(_selectedAmount);
              _invalidateOrder();
            });
          },
          onFieldSubmitted: (_) {
            if (_selectedAmount != null && _selectedAmount!.isNotEmpty) {
              final val = double.tryParse(_selectedAmount!) ?? 0;
              if (val < min || val > max) {
                setState(() {
                  _setAmount(null);
                  _invalidateOrder();
                });
              }
            }
          },
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF3E3E3E),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDAD5FF), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF9747FF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDAD5FF), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF9747FF), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Cashback preview
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '+₹$cashback cashback',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF10B981),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySection(double amount) {
    final total = amount * _quantity;
    final discount = double.tryParse(widget.brand?.discount ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Quantity:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _quantity > 1
                    ? setState(() {
                        _quantity--;
                        _invalidateOrder();
                      })
                    : null,
                child: Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6C5CE7)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.remove,
                    size: 18,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _quantity >= 3
                    ? null
                    : () => setState(() {
                        _quantity++;
                        _invalidateOrder();
                      }),
                child: Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6C5CE7)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: Color(0xFF6C5CE7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total: ₹${amount.toInt()} x $_quantity = ₹${total.toInt()}${discount > 0 && _payMode == 0 ? ' + ₹${(total * discount / 100).toInt()} cashback' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTabs(Brand brand) {
    final about =
        _nonEmptyText(brand.description) ?? 'No description available.';
    final howToUse =
        _nonEmptyText(brand.howToUse) ??
        _nonEmptyText(brand.importantInstruction) ??
        'No instructions available.';
    final terms = _nonEmptyText(brand.terms) ?? 'No terms available.';

    return Column(
      children: [
        // Tab buttons row
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoTabButton('i', 'About', 'about', 71),
              _buildInfoTabButton('*', 'How to Use', 'howtouse', 102),
              _buildInfoTabButton('#', 'Terms', 'terms', 73),
            ],
          ),
        ),
        // Expandable content
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _infoTab == 'about'
              ? _buildInfoContent(about, false)
              : _infoTab == 'howtouse'
              ? _buildInfoContent(howToUse, false)
              : _infoTab == 'terms'
              ? _buildInfoContent(terms, true)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String? _nonEmptyText(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  Brand _brandWithFetchedDetails(Brand base) {
    final details = _detailedBrand;
    if (details == null || details.brandId != base.brandId) return base;
    final howToUse =
        _nonEmptyText(details.howToUse) ??
        _nonEmptyText(details.importantInstruction) ??
        _nonEmptyText(base.howToUse) ??
        _nonEmptyText(base.importantInstruction);
    return base.copyWith(
      description: _nonEmptyText(details.description) ?? base.description,
      howToUse: howToUse,
      importantInstruction:
          _nonEmptyText(details.importantInstruction) ??
          base.importantInstruction,
      terms: _nonEmptyText(details.terms) ?? base.terms,
    );
  }

  Widget _buildInfoTabButton(
    String symbol,
    String label,
    String tab,
    double width,
  ) {
    final isSelected = _infoTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _infoTab = isSelected ? '' : tab),
      child: Container(
        width: width,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEAFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF9747FF),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF9747FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContent(String content, bool isTerms) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.5,
            color: const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  /// Shows the success animation (matches AddToCartSuccessModal.tsx) as an
  /// independent overlay route so it keeps playing/self-closes on its own
  /// timer even if the underlying sheet is torn down by the parent's
  /// (unchanged) onAddToCart flow immediately after this is called.
  void _showAddToCartSuccess(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors
          .transparent, // AddToCartSuccessModal paints its own dim backdrop
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });
        return AddToCartSuccessModal(
          open: true,
          onClose: () => Navigator.of(dialogContext).maybePop(),
        );
      },
    );
  }

  Widget _buildBottomBar(Brand brand, double total, int cashback) {
    final processing = widget.processing || _isPaying;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: processing
                  ? null
                  : () {
                      _showAddToCartSuccess(context);
                      widget.onAddToCart(
                        brand,
                        double.parse(_selectedAmount ?? '0'),
                        _quantity,
                      );
                    },
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  gradient: !processing
                      ? const LinearGradient(
                          colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: !processing ? null : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Opacity(
                    opacity: processing ? 0.7 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              // Staged like React: Buy Now opens the pay panel where the
              // reward mode is chosen; UPI/method selection only happens
              // when Pay is pressed inside that panel.
              onTap: processing
                  ? null
                  : () => setState(() => _payPanelOpen = true),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: !processing ? Colors.white : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !processing
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFFD1D5DB),
                  ),
                  boxShadow: !processing
                      ? const [
                          BoxShadow(
                            color: Color(0x14111827),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Buy Now',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6C5CE7),
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

  void _chooseMode(int mode) {
    if (mode != _payMode) _switchPayMode(mode);
    setState(() => _modeChosen = true);
  }

  Future<void> _confirmPayFromPanel(Brand brand) async {
    final amount = double.tryParse(_selectedAmount ?? '') ?? 0;
    setState(() {
      _payPanelOpen = false;
    });
    await _handlePayPressed(brand, amount, _quantity);
  }

  String _earnText(_SheetPricing pricing, double discountPercent) {
    if (_payMode == 1) {
      final earnKey = superCoinEarnKey([
        MapEntry(widget.brand?.brandId ?? '', pricing.total),
      ], pricing.cash);
      final scEarn =
          ref.watch(superCoinEarnEstimateProvider(earnKey)).valueOrNull ?? 0.0;
      return 'Earn ${scEarn.toStringAsFixed(2)} SuperCoins';
    }
    return 'Earn ${(pricing.cash * (discountPercent / 100)).toStringAsFixed(2)} cashback points'
        '${discountPercent > 0 ? ' (${discountPercent.toStringAsFixed(0)}%)' : ''}';
  }

  /// PayUsingField (React): "PAY USING ^ / method / subtext" on the left and the
  /// amount on the right — tapping opens the "Pay using" chooser.
  Widget _payActionButton({
    required VoidCallback? onTap,
    required bool processing,
    required String label,
    String methodLabel = 'UPI',
    String methodSubtext = 'Google Pay, PhonePe, Paytm, CRED, BHIM',
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: !processing
              ? const LinearGradient(
                  colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                )
              : null,
          color: processing ? const Color(0xFFD1D5DB) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: processing
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
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
                    methodLabel,
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
                    methodSubtext,
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
              processing ? 'Please wait.' : label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeOptionCard({
    required Widget icon,
    required String title,
    required String subtitle,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9747FF).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF9747FF) : const Color(0xFFE5E7EB),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(width: 44, height: 44, child: Center(child: icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF101010),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelHeader(
    _SheetPricing pricing, {
    required VoidCallback onClose,
    required String earnText,
  }) {
    return Row(
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
                '\u20b9${pricing.totalPay.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9747FF),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                earnText,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  Widget _buildPayPanel(Brand brand) {
    final discountPercent = double.tryParse(brand.discount ?? '0') ?? 0;
    final amount = double.tryParse(_selectedAmount ?? '') ?? 0;
    final total = amount * _quantity;
    ref.watch(superCoinConfigProvider);
    ref.watch(superCoinBrandSharesProvider);
    final pricing = _pricing(brand, total, discountPercent);
    final scState = ref.watch(supercoinProvider);
    ref.watch(walletBalanceProvider);
    final processing = widget.processing || _isPaying;
    final sliderMax = pricing.maxSC >= 1 ? pricing.maxSC : 1.0;
    final sliderValue = _scPreviewOff
        ? 0.0
        : pricing.selectedSC.clamp(0.0, sliderMax);

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _payPanelOpen = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: GestureDetector(
            onTap: () {},
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelHeader(
                        pricing,
                        earnText: _earnText(pricing, discountPercent),
                        onClose: () => setState(() => _payPanelOpen = false),
                      ),
                      const SizedBox(height: 14),
                      if (!_modeChosen) ...[
                        _modeOptionCard(
                          icon: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF9747FF),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          title: 'Pay via cash/wallet',
                          subtitle: 'UPI, cards, netbanking & more',
                          selected: false,
                          onTap: processing ? null : () => _chooseMode(0),
                        ),
                        if (pricing.scEligible) ...[
                          const SizedBox(height: 10),
                          _modeOptionCard(
                            icon: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                'assets/images/SuperCOin-removebg-preview.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                            title: 'Pay via Cash+SuperCoins',
                            subtitle: 'Redeem SuperCoins, pay the rest by cash',
                            selected: false,
                            onTap: processing ? null : () => _chooseMode(1),
                          ),
                        ],
                      ] else ...[
                        if (_payMode == 0)
                          _buildWalletToggle(pricing)
                        else
                          _buildSuperCoinControls(
                            pricing,
                            scState,
                            sliderMax,
                            sliderValue,
                          ),
                        const SizedBox(height: 10),
                        _summaryLine(
                          'Total',
                          '\u20b9${pricing.total.toStringAsFixed(2)}',
                        ),
                        if (pricing.wallet > 0)
                          _summaryLine(
                            'Cashback points to redeem',
                            '-\u20b9${pricing.wallet.toStringAsFixed(2)}',
                            color: const Color(0xFF059669),
                          ),
                        if (_payMode == 1)
                          _summaryLine(
                            'SuperCoins to redeem',
                            '-\u20b9${pricing.scDeduction.toStringAsFixed(2)}',
                            color: pricing.scDeduction > 0
                                ? const Color(0xFF059669)
                                : const Color(0xFF6B7280),
                          ),
                        _summaryLine(
                          'Platform Fee${pricing.method != null ? ' \u00b7 ${pricing.method!.label}' : ''}',
                          '\u20b9${pricing.fee.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        _payActionButton(
                          processing: processing,
                          methodLabel: pricing.method?.label ?? 'UPI',
                          methodSubtext: _payMethodSubtext(
                            pricing.method?.code,
                          ),
                          label: (_isPaying || processing)
                              ? 'Processing\u2026'
                              : 'Pay \u20b9${pricing.totalPay.toStringAsFixed(2)}',
                          onTap: processing
                              ? null
                              : () => _confirmPayFromPanel(brand),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryLine(
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: bold ? 15 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color:
                  color ??
                  (bold ? const Color(0xFF9747FF) : const Color(0xFF101010)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletToggle(_SheetPricing pricing) {
    final enabled = pricing.walletBalance > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF9747FF).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9747FF).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: Color(0xFF9747FF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use cashback points',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  enabled
                      ? '${pricing.walletBalance.toStringAsFixed(2)} points available \u00b7 use up to ${pricing.maxWalletUsage.toStringAsFixed(2)} here'
                      : 'No cashback points yet',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _useWalletBalance,
            onChanged: enabled
                ? (v) => setState(() => _useWalletBalance = v)
                : null,
            activeThumbColor: const Color(0xFF9747FF),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperCoinControls(
    _SheetPricing pricing,
    SuperCoinState scState,
    double sliderMax,
    double sliderValue,
  ) {
    if (!scState.isEnrolled) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF9747FF).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Register on Flipkart SuperCoin to earn & redeem coins on every purchase.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF6B7280),
          ),
        ),
      );
    }
    if (_superCoinAuthorized && _superCoinHoldContext != null) {
      final mins = (_scCountdownSeconds ~/ 60).toString().padLeft(2, '0');
      final secs = (_scCountdownSeconds % 60).toString().padLeft(2, '0');
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD1FAE5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/SuperCOin-removebg-preview.png',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_superCoinHoldContext!.amount.toStringAsFixed(0)} coins applied \u00b7 saving \u20b9${pricing.scDeduction.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _unholdSuperCoinIfNeeded();
                    setState(() {});
                  },
                  child: Text(
                    'Remove',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            if (!_scCountdownExpired && _scCountdownSeconds > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 13,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pay within $mins:$secs',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ],
            if (_scCountdownExpired) ...[
              const SizedBox(height: 6),
              Text(
                'SuperCoin hold expired. Please apply again.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (pricing.maxSC < 1) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          scState.balance <= 0
              ? "No SuperCoins to use right now. You'll still earn coins on this order."
              : "SuperCoins can't be used on this voucher.",
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF6B7280),
          ),
        ),
      );
    }
    final divisions = sliderMax >= 2 ? sliderMax.round() : 1;
    return Container(
      padding: const EdgeInsets.all(10),
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
            children: [
              Image.asset(
                'assets/images/SuperCOin-removebg-preview.png',
                width: 14,
                height: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Use SuperCoins',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const Spacer(),
              Text(
                '${_scPreviewOff ? 0 : pricing.selectedSC.toStringAsFixed(0)} coins',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF9747FF),
              inactiveTrackColor: const Color(
                0xFF9747FF,
              ).withValues(alpha: 0.2),
              thumbColor: const Color(0xFF9747FF),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              min: 0,
              max: sliderMax,
              divisions: divisions,
              value: sliderValue,
              onChanged: (v) {
                if (v < 1) {
                  setState(() => _scPreviewOff = true);
                } else {
                  setState(() {
                    _scPreviewOff = false;
                    _selectedSCCoins = v;
                  });
                }
              },
            ),
          ),
          Row(
            children: [
              Text(
                'Balance ${scState.balance.toStringAsFixed(0)} \u00b7 max ${pricing.maxSC.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Text(
                '\u20b91 = ${pricing.multiplier == pricing.multiplier.roundToDouble() ? pricing.multiplier.toStringAsFixed(0) : pricing.multiplier.toStringAsFixed(2)} SC',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<double> _parseDenominations(String? denomination) {
    if (denomination == null || denomination.isEmpty) return [];
    return denomination
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }
}

/// Matches the reference app's `.payment-range::-webkit-slider-thumb`:
/// a 15px purple circle with a thin white ring around it.
class _SheetPricing {
  final double total;
  final double wallet;
  final double scDeduction;
  final double cash;
  final double fee;
  final double totalPay;
  final double maxSC;
  final double selectedSC;
  final bool scEligible;
  final double multiplier;
  final double maxWalletUsage;
  final double walletBalance;
  final PaymentMethodFee? method;

  const _SheetPricing({
    required this.total,
    required this.wallet,
    required this.scDeduction,
    required this.cash,
    required this.fee,
    required this.totalPay,
    required this.maxSC,
    required this.selectedSC,
    required this.scEligible,
    required this.multiplier,
    required this.maxWalletUsage,
    required this.walletBalance,
    required this.method,
  });
}
