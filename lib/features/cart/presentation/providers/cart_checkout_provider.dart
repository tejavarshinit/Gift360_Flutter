import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/data/utils/supercoin_redemption.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/wallet/data/utils/wallet_redemption.dart';
import 'package:gift360/features/home/presentation/providers/home_providers.dart';
import 'package:gift360/features/payment/data/models/payment_method_fee.dart';
import 'package:gift360/core/utils/analytics.dart';

enum RewardMode { cashbackWallet, superCoins }

// ── Checkout State ──
class CartCheckoutState {
  final RewardMode rewardMode;
  final bool useWalletBalance;
  final Map<String, double> brandDiscounts;
  final Map<String, double> brandSupercoinMultipliers;
  final bool brandDiscountsLoading;

  // SuperCoin hold
  final bool superCoinAuthorized;
  final SuperCoinHoldContext? superCoinHoldContext;
  final String? superCoinOrderNumber;
  final int superCoinCountdownSeconds;
  final bool superCoinCountdownExpired;
  final String? superCoinTransactionTime;

  // Cart slider selection (mirrors React `selectedSCCoins`): coins the user
  // picked before applying the SuperCoin hold. 0 = not chosen yet (defaults
  // to the max redeemable until the user drags).
  final double selectedSuperCoinCoins;

  // Selected cash payment method (UPI/DC/CC/NB) — drives the DB-backed
  // platform fee. Defaults to UPI like React (`selectedPaymentMethod`).
  final String selectedPaymentMethod;

  // Payment
  final bool isProcessing;

  const CartCheckoutState({
    this.rewardMode = RewardMode.cashbackWallet,
    this.useWalletBalance = false,
    this.brandDiscounts = const {},
    this.brandSupercoinMultipliers = const {},
    this.brandDiscountsLoading = false,
    this.superCoinAuthorized = false,
    this.superCoinHoldContext,
    this.superCoinOrderNumber,
    this.superCoinCountdownSeconds = 900,
    this.superCoinCountdownExpired = false,
    this.superCoinTransactionTime,
    this.selectedSuperCoinCoins = 0,
    this.selectedPaymentMethod = 'UPI',
    this.isProcessing = false,
  });

  CartCheckoutState copyWith({
    RewardMode? rewardMode,
    bool? useWalletBalance,
    Map<String, double>? brandDiscounts,
    Map<String, double>? brandSupercoinMultipliers,
    bool? brandDiscountsLoading,
    bool? superCoinAuthorized,
    SuperCoinHoldContext? superCoinHoldContext,
    String? superCoinOrderNumber,
    int? superCoinCountdownSeconds,
    bool? superCoinCountdownExpired,
    String? superCoinTransactionTime,
    double? selectedSuperCoinCoins,
    String? selectedPaymentMethod,
    bool? isProcessing,
    bool clearHold = false,
    bool clearError = false,
  }) {
    return CartCheckoutState(
      rewardMode: rewardMode ?? this.rewardMode,
      useWalletBalance: useWalletBalance ?? this.useWalletBalance,
      brandDiscounts: brandDiscounts ?? this.brandDiscounts,
      brandSupercoinMultipliers:
          brandSupercoinMultipliers ?? this.brandSupercoinMultipliers,
      brandDiscountsLoading:
          brandDiscountsLoading ?? this.brandDiscountsLoading,
      superCoinAuthorized: superCoinAuthorized ?? this.superCoinAuthorized,
      superCoinHoldContext: clearHold
          ? null
          : (superCoinHoldContext ?? this.superCoinHoldContext),
      superCoinOrderNumber: clearHold
          ? null
          : (superCoinOrderNumber ?? this.superCoinOrderNumber),
      superCoinCountdownSeconds:
          superCoinCountdownSeconds ?? this.superCoinCountdownSeconds,
      superCoinCountdownExpired:
          superCoinCountdownExpired ?? this.superCoinCountdownExpired,
      superCoinTransactionTime: clearHold
          ? null
          : (superCoinTransactionTime ?? this.superCoinTransactionTime),
      selectedSuperCoinCoins:
          selectedSuperCoinCoins ?? this.selectedSuperCoinCoins,
      selectedPaymentMethod:
          selectedPaymentMethod ?? this.selectedPaymentMethod,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

// ── Checkout Notifier ──
class CartCheckoutNotifier extends StateNotifier<CartCheckoutState> {
  final SuperCoinApi _superCoinApi;
  final String? _mobile;
  Timer? _countdownTimer;

  CartCheckoutNotifier(this._superCoinApi, this._mobile)
    : super(const CartCheckoutState());

  SuperCoinIdentity? get _identity {
    final normalized = normalizeMobileToE164(_mobile);
    if (normalized == null) return null;
    return SuperCoinIdentity(identifier: normalized, type: 'MOBILE');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Reward Mode ──
  void setRewardMode(RewardMode mode) {
    if (mode == RewardMode.superCoins) {
      state = state.copyWith(
        rewardMode: RewardMode.superCoins,
        useWalletBalance: false,
      );
    } else {
      // Cancel supercoin hold when switching to cashback
      if (state.superCoinAuthorized) {
        cancelSuperCoinHold();
        // Fire analytics: supercoin removed
        AnalyticsService.trackSuperCoinRemoved(
          amount: state.superCoinHoldContext?.amount ?? 0,
        );
      }
      state = state.copyWith(
        rewardMode: RewardMode.cashbackWallet,
        superCoinAuthorized: false,
        clearHold: true,
        superCoinCountdownSeconds: 900,
        superCoinCountdownExpired: false,
      );
    }
  }

  // ── Wallet ──
  void toggleWallet() {
    state = state.copyWith(useWalletBalance: !state.useWalletBalance);
  }

  // ── Cash payment method (React `setSelectedPaymentMethod`) ──
  void setSelectedPaymentMethod(String code) {
    if (state.selectedPaymentMethod == code) return;
    state = state.copyWith(selectedPaymentMethod: code);
  }

  // ── SuperCoin slider selection (React `setSelectedSCCoins`) ──
  void setSelectedSuperCoinCoins(double coins) {
    if (state.selectedSuperCoinCoins == coins) return;
    state = state.copyWith(selectedSuperCoinCoins: coins);
  }

  // ── Brand Discounts + SuperCoin multipliers ──
  Future<void> fetchBrandDiscounts(
    List<CartItem> cartItems,
    dynamic brandsApi,
  ) async {
    final uniqueBrandIds = cartItems.map((i) => i.brandId).toSet().toList();
    final unknownIds = uniqueBrandIds
        .where((id) => !state.brandDiscounts.containsKey(id))
        .toList();
    if (unknownIds.isEmpty) return;

    state = state.copyWith(brandDiscountsLoading: true);
    try {
      final results = await Future.wait(
        unknownIds.map((brandId) async {
          try {
            final brand = await brandsApi.getBrandById(brandId);
            final discount = double.tryParse(brand.discount ?? '0') ?? 0;
            final multiplier = brand.supercoinMultiplier ?? 1.25;
            return (brandId, discount, multiplier);
          } catch (_) {
            return (brandId, 0.0, 1.25);
          }
        }),
      );
      final discounts = Map<String, double>.from(state.brandDiscounts);
      final multipliers = Map<String, double>.from(
        state.brandSupercoinMultipliers,
      );
      for (final (brandId, discount, multiplier) in results) {
        discounts[brandId] = discount;
        multipliers[brandId] = multiplier;
      }
      state = state.copyWith(
        brandDiscounts: discounts,
        brandSupercoinMultipliers: multipliers,
        brandDiscountsLoading: false,
      );
    } catch (_) {
      state = state.copyWith(brandDiscountsLoading: false);
    }
  }

  // ── SuperCoin Hold ──
  void onSuperCoinAuthorized(SuperCoinHoldContext context, String orderNumber) {
    _countdownTimer?.cancel();
    state = state.copyWith(
      superCoinAuthorized: true,
      superCoinHoldContext: context,
      superCoinOrderNumber: orderNumber,
      superCoinTransactionTime: context.transactionTime,
      superCoinCountdownExpired: false,
    );
    _startCountdown(context);
    // Fire analytics: supercoin used
    AnalyticsService.trackSuperCoinUsed(amount: context.amount);
  }

  void _startCountdown(SuperCoinHoldContext holdContext) {
    _countdownTimer?.cancel();
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

    state = state.copyWith(superCoinCountdownSeconds: remaining);

    if (remaining <= 0) {
      state = state.copyWith(
        superCoinCountdownExpired: true,
        superCoinAuthorized: false,
        clearHold: true,
      );
      SuperCoinOtpNotifier.loadActiveOrderNumber().then((
        activeOrderNumber,
      ) async {
        if (activeOrderNumber != null && activeOrderNumber.isNotEmpty) {
          await SuperCoinOtpNotifier.clearHoldContext(activeOrderNumber);
        }
        await SuperCoinOtpNotifier.clearActiveOrderNumber();
      });
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final next = state.superCoinCountdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(
          superCoinCountdownSeconds: 0,
          superCoinCountdownExpired: true,
          superCoinAuthorized: false,
          clearHold: true,
        );
        // Expiry is terminal for this hold; remove both persisted references.
        final activeOrderNumber =
            await SuperCoinOtpNotifier.loadActiveOrderNumber();
        if (activeOrderNumber != null && activeOrderNumber.isNotEmpty) {
          await SuperCoinOtpNotifier.clearHoldContext(activeOrderNumber);
        }
        await SuperCoinOtpNotifier.clearActiveOrderNumber();
      } else {
        state = state.copyWith(superCoinCountdownSeconds: next);
      }
    });
  }

  Future<void> cancelSuperCoinHold({String? orderNumber}) async {
    await cancelSuperCoinHoldIfNeeded(identity: _identity);
    // Also clear persisted active order number on cold start.
    await SuperCoinOtpNotifier.clearActiveOrderNumber();
  }

  /// Cancel the active SuperCoin hold if one exists, sending the identity
  /// payload with the unhold request (matches React's cancelSuperCoinHold).
  Future<void> cancelSuperCoinHoldIfNeeded({
    SuperCoinIdentity? identity,
  }) async {
    final holdContext = state.superCoinHoldContext;
    if (holdContext != null) {
      try {
        await _superCoinApi.unhold({
          'identity':
              identity?.toJson() ?? {'identifier': '', 'type': 'MOBILE'},
          'merchantTransactionId': holdContext.merchantTransactionId,
          'merchantWalletId': holdContext.merchantWalletId,
        });
      } catch (_) {}
    }
    _countdownTimer?.cancel();
    state = state.copyWith(
      superCoinAuthorized: false,
      clearHold: true,
      superCoinCountdownSeconds: 900,
      superCoinCountdownExpired: false,
    );
  }

  void setProcessing(bool value) {
    state = state.copyWith(isProcessing: value);
  }

  void reset() {
    _countdownTimer?.cancel();
    state = const CartCheckoutState();
  }
}

// ── Providers ──
final cartCheckoutProvider =
    StateNotifierProvider.autoDispose<CartCheckoutNotifier, CartCheckoutState>((
      ref,
    ) {
      final superCoinApi = ref.watch(supercoinApiProvider);
      final user = ref.watch(authProvider);
      return CartCheckoutNotifier(superCoinApi, user?.mobile);
    });

// ── Derived Calculation Providers ──

/// Brand totals grouped by brand+unitValue
final brandTotalsProvider = Provider.autoDispose<Map<String, BrandTotal>>((
  ref,
) {
  final cart = ref.watch(cartProvider);
  final discounts = ref.watch(
    cartCheckoutProvider.select((s) => s.brandDiscounts),
  );
  if (cart == null || cart.items.isEmpty) return {};

  final map = <String, BrandTotal>{};
  for (final item in cart.items) {
    final key = '${item.brandId}-${item.unitValue}';
    final discount = (item.discount ?? discounts[item.brandId] ?? 0).toDouble();
    if (map.containsKey(key)) {
      final existing = map[key]!;
      map[key] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
        total: existing.total + item.lineTotal,
      );
    } else {
      map[key] = BrandTotal(
        brand: item.brandName,
        brandId: item.brandId,
        quantity: item.quantity,
        price: item.unitValue,
        total: item.lineTotal,
        discount: discount,
      );
    }
  }
  return map;
});

class BrandTotal {
  final String brand;
  final String brandId;
  final int quantity;
  final double price;
  final double total;
  final double discount;

  const BrandTotal({
    required this.brand,
    required this.brandId,
    required this.quantity,
    required this.price,
    required this.total,
    required this.discount,
  });

  BrandTotal copyWith({int? quantity, double? total}) {
    return BrandTotal(
      brand: brand,
      brandId: brandId,
      quantity: quantity ?? this.quantity,
      price: price,
      total: total ?? this.total,
      discount: discount,
    );
  }
}

/// Payment breakdown
class PaymentBreakdown {
  final double subtotal;
  final double processingFee;
  final double couponDiscount;
  final double couponAdjustedAmount;
  final double walletDeduction;
  final double maxWalletUsage;
  final double superCoinDeduction;
  final double finalPayable;
  final double cashbackPercent;
  final double cashbackAmount;

  /// Cash paid for the vouchers (excludes the platform fee) after the wallet and
  /// the SuperCoin deduction — authorised hold, or the slider preview while the
  /// OTP hold is still pending. Backend earn estimates and cashback are based on
  /// this, exactly like React Cart's `displayCash`.
  final double displayCash;
  final double maxSuperCoinRedeemable;
  final double effectiveSupercoinMultiplier;
  final double estimatedEarn;

  /// Active cash payment method (from the DB fee table) used for
  /// [processingFee]. Null when the fee table could not load and the legacy
  /// platform fee is in effect.
  final String? paymentMethodCode;
  final String? paymentMethodLabel;

  const PaymentBreakdown({
    required this.subtotal,
    required this.processingFee,
    required this.couponDiscount,
    required this.couponAdjustedAmount,
    required this.walletDeduction,
    required this.maxWalletUsage,
    required this.superCoinDeduction,
    required this.finalPayable,
    required this.cashbackPercent,
    required this.cashbackAmount,
    required this.displayCash,
    required this.maxSuperCoinRedeemable,
    required this.effectiveSupercoinMultiplier,
    required this.estimatedEarn,
    this.paymentMethodCode,
    this.paymentMethodLabel,
  });
}

final paymentBreakdownProvider = Provider.autoDispose<PaymentBreakdown>((ref) {
  final cart = ref.watch(cartProvider);
  final checkout = ref.watch(cartCheckoutProvider);
  final walletAsync = ref.watch(walletBalanceProvider);
  final superCoinState = ref.watch(supercoinProvider);
  final superCoinConfigAsync = ref.watch(superCoinConfigProvider);
  final superCoinConfig =
      superCoinConfigAsync.hasValue && !superCoinConfigAsync.hasError
      ? superCoinConfigAsync.valueOrNull
      : null;
  final platformFeeAsync = ref.watch(platformFeeConfigProvider).valueOrNull;

  final subtotal = cart?.totalAmount ?? 0;
  const couponDiscount = 0.0; // Coupon hidden for now

  // ── Wallet cap — exact integer HALF_UP math (matches React walletCapPaise) ──
  // cashbackValue = sum of per-item itemCashbackScale4(lineTotal, pct).
  // maxWalletUsage = min(cashbackValue * redeemPercent / 100, maxRedeemAmount).
  final walletData = walletAsync.value;
  final cashbackRedeemPercent = walletData?.cashbackRedeemPercent ?? 50.0;
  final maxRedeemAmount = walletData?.maxRedeemAmount ?? 100.0;
  int cartCashbackValueScale4 = 0;
  if (cart != null && cart.items.isNotEmpty) {
    cartCashbackValueScale4 = cart.items.fold(0, (sum, item) {
      final pct = item.discount ?? checkout.brandDiscounts[item.brandId] ?? 0;
      return sum + walletItemCashbackScale4(item.lineTotal, pct);
    });
  }
  final maxWalletUsage =
      walletRedemptionCapPaise(
        cartCashbackValueScale4,
        cashbackRedeemPercent,
        maxRedeemAmount,
      ) /
      100;

  final walletBalance = (walletAsync.value?.totalBalance ?? 0).toDouble();
  final walletDeduction = checkout.useWalletBalance
      ? (walletBalance < maxWalletUsage ? walletBalance : maxWalletUsage)
      : 0.0;

  // ── SuperCoin cap — per-item, NOT flat (matches React Cart.tsx) ──
  // per eligible item: itemCoinCap = ceil(itemTotal × capPercent/100 × multiplier)
  // totalCoinCap = sum(itemCoinCap), totalRupeeCap = sum(itemRupeeCap)
  // effectiveSupercoinMultiplier = totalCoinCap / totalRupeeCap (or 1.25)
  final capPercent = superCoinConfig?.capPercent ?? 20.0;
  // Per-brand share (V51) overrides the global cap and can exclude a brand
  // (share 0) exactly like React Cart's isScExcluded / brandCapShare.
  final brandShares =
      ref.watch(superCoinBrandSharesProvider).valueOrNull ??
      const <String, double>{};
  bool isScExcluded(dynamic item) => isSuperCoinExcludedWithShares(
    brandShares,
    brandId: item.brandId,
    brandName: item.brandName,
  );
  final allItemsSuperCoinExcluded =
      cart != null && cart.items.isNotEmpty && cart.items.every(isScExcluded);

  double totalRupeeCap = 0;
  double totalCoinCap = 0;
  final discountsLoaded =
      cart == null ||
      cart.items.every(
        (item) =>
            item.discount != null ||
            item.hasDiscountField ||
            checkout.brandDiscounts.containsKey(item.brandId),
      );
  if (cart != null && cart.items.isNotEmpty && discountsLoaded) {
    for (final item in cart.items) {
      if (isScExcluded(item)) continue;
      final multiplier =
          checkout.brandSupercoinMultipliers[item.brandId] ?? 1.25;
      final itemCapPercent =
          superCoinCapShare(brandShares, item.brandId) ?? capPercent;
      final itemTotal = item.quantity * item.unitValue;
      final itemRupeeCap = itemTotal * (itemCapPercent / 100);
      final itemCoinCap = supercoinItemCapCoins(
        itemTotal: itemTotal,
        capPercent: itemCapPercent,
        multiplier: multiplier,
      ).toDouble();
      totalRupeeCap += itemRupeeCap;
      totalCoinCap += itemCoinCap;
    }
  }
  final maxSuperCoinRedeemable = discountsLoaded
      ? totalCoinCap
      : superCoinState.balance;
  final effectiveSupercoinMultiplier = discountsLoaded && totalRupeeCap > 0
      ? totalCoinCap / totalRupeeCap
      : 1.25;

  final holdAmount =
      checkout.superCoinHoldContext?.amount ?? superCoinState.balance;
  final superCoinDeduction =
      !allItemsSuperCoinExcluded &&
          checkout.superCoinAuthorized &&
          superCoinState.isEnrolled &&
          holdAmount > 0
      ? [
              holdAmount,
              maxSuperCoinRedeemable,
              superCoinState.balance,
            ].reduce((a, b) => a < b ? a : b) /
            effectiveSupercoinMultiplier
      : 0.0;

  // ── Platform fee ──
  // Primary: the DB-backed per-method fee (UPI/DC/CC percent, NB flat) from
  // /v1/payment-method-fees, computed on the cash payable BEFORE the fee.
  // Fallback (fee table unavailable, older backend): the legacy mode-based
  // percent of face value, still always charged (React Cart.tsx).
  final feeMethods =
      ref.watch(paymentMethodFeesProvider).valueOrNull ??
      const <PaymentMethodFee>[];
  final selectedMethod = activePaymentMethod(
    feeMethods,
    checkout.selectedPaymentMethod,
  );
  final useMethodFee = feeMethods.isNotEmpty;

  // React: couponAdjustedAmount = Math.max(0, subtotal - couponDiscount)
  final couponAdjustedAmount = (subtotal - couponDiscount)
      .clamp(0.0, double.infinity)
      .toDouble();
  // React: cashBeforeFee = max(0, couponAdjusted - wallet - superCoin)
  final cashBeforeFee =
      (couponAdjustedAmount - walletDeduction - superCoinDeduction)
          .clamp(0.0, double.infinity)
          .toDouble();

  final inSuperCoinMode = checkout.rewardMode == RewardMode.superCoins;
  // Display preview (React Cart): while the slider is moved but the hold isn't
  // authorised yet, the on-screen total previews the coins; payment itself
  // still uses only the authorised hold.
  final previewSCCoins = checkout.selectedSuperCoinCoins < 1
      ? maxSuperCoinRedeemable
      : math.min(checkout.selectedSuperCoinCoins, maxSuperCoinRedeemable);
  final scPreviewDeduction =
      (inSuperCoinMode &&
          !checkout.superCoinAuthorized &&
          !allItemsSuperCoinExcluded &&
          superCoinState.isEnrolled &&
          maxSuperCoinRedeemable >= 1 &&
          previewSCCoins >= 1)
      ? math.min(
          previewSCCoins / effectiveSupercoinMultiplier,
          couponAdjustedAmount,
        )
      : 0.0;
  final displaySCDeduction = superCoinDeduction > 0
      ? superCoinDeduction
      : scPreviewDeduction;
  final displayCash =
      (couponAdjustedAmount - walletDeduction - displaySCDeduction)
          .clamp(0.0, double.infinity)
          .toDouble();
  // NOTE: keys resolved first — Dart's parser chokes on `cond ? map?['k'] : ...`
  // (nested ternary vs `?[]` ambiguity), so never inline the lookup in a ternary.
  final feePercentKey = inSuperCoinMode ? 'feePercent' : 'feePercentCash';
  final feeMaxKey = inSuperCoinMode ? 'feeMax' : 'feeMaxCash';
  final feePercent =
      (platformFeeAsync?[feePercentKey] as num?)?.toDouble() ?? 0.02;
  final feeMax = (platformFeeAsync?[feeMaxKey] as num?)?.toDouble() ?? 20.0;
  final rawFee = subtotal * feePercent;
  // Backend order: fee.setScale(2, HALF_UP) then .min(feeMax) — match exactly.
  final roundedFee = (rawFee * 100).roundToDouble() / 100;
  final legacyFee = roundedFee < feeMax ? roundedFee : feeMax;

  final processingFee = useMethodFee
      ? computeMethodFee(selectedMethod, cashBeforeFee)
      : legacyFee;

  // React: finalPayable = cashBeforeFee + PLATFORM_FEE
  final finalPayable = cashBeforeFee + processingFee;

  // Cashback % (weighted average)
  double cashbackPercent = 0;
  if (cart != null && cart.items.isNotEmpty) {
    final totalLine = cart.items.fold(0.0, (s, i) => s + i.lineTotal);
    if (totalLine > 0) {
      cashbackPercent = cart.items.fold(0.0, (sum, item) {
        final disc =
            item.discount ?? checkout.brandDiscounts[item.brandId] ?? 0;
        return sum + (item.lineTotal / totalLine) * disc;
      });
    }
  }
  // Cashback is on the voucher cash paid, not the platform fee (React Cart).
  final cashbackAmount = displayCash * (cashbackPercent / 100);
  // Deprecated: the SuperCoin earn estimate now comes from the backend
  // (superCoinEarnEstimateProvider). Kept at 0 so no misleading 1% is shown.
  const estimatedEarn = 0.0;

  return PaymentBreakdown(
    subtotal: subtotal,
    processingFee: processingFee,
    couponDiscount: couponDiscount,
    couponAdjustedAmount: couponAdjustedAmount,
    walletDeduction: walletDeduction,
    maxWalletUsage: maxWalletUsage,
    superCoinDeduction: superCoinDeduction,
    finalPayable: finalPayable,
    cashbackPercent: cashbackPercent,
    cashbackAmount: cashbackAmount,
    displayCash: displayCash,
    maxSuperCoinRedeemable: maxSuperCoinRedeemable,
    effectiveSupercoinMultiplier: effectiveSupercoinMultiplier,
    estimatedEarn: estimatedEarn,
    paymentMethodCode: useMethodFee ? selectedMethod?.code : null,
    paymentMethodLabel: useMethodFee ? selectedMethod?.label : null,
  );
});
