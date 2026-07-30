import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';

enum RewardMode { cashbackWallet, superCoins }

// ── Checkout State ──
class CartCheckoutState {
  final RewardMode rewardMode;
  final bool useWalletBalance;
  final Map<String, double> brandDiscounts;
  final bool brandDiscountsLoading;

  // SuperCoin hold
  final bool superCoinAuthorized;
  final SuperCoinHoldContext? superCoinHoldContext;
  final String? superCoinOrderNumber;
  final int superCoinCountdownSeconds;
  final bool superCoinCountdownExpired;
  final String? superCoinTransactionTime;

  // Payment
  final bool isProcessing;
  final String? paymentError;
  final String? paymentStatus; // 'loading', 'success'

  const CartCheckoutState({
    this.rewardMode = RewardMode.cashbackWallet,
    this.useWalletBalance = false,
    this.brandDiscounts = const {},
    this.brandDiscountsLoading = false,
    this.superCoinAuthorized = false,
    this.superCoinHoldContext,
    this.superCoinOrderNumber,
    this.superCoinCountdownSeconds = 900,
    this.superCoinCountdownExpired = false,
    this.superCoinTransactionTime,
    this.isProcessing = false,
    this.paymentError,
    this.paymentStatus,
  });

  CartCheckoutState copyWith({
    RewardMode? rewardMode,
    bool? useWalletBalance,
    Map<String, double>? brandDiscounts,
    bool? brandDiscountsLoading,
    bool? superCoinAuthorized,
    SuperCoinHoldContext? superCoinHoldContext,
    String? superCoinOrderNumber,
    int? superCoinCountdownSeconds,
    bool? superCoinCountdownExpired,
    String? superCoinTransactionTime,
    bool? isProcessing,
    String? paymentError,
    String? paymentStatus,
    bool clearHold = false,
    bool clearError = false,
    bool clearPaymentStatus = false,
  }) {
    return CartCheckoutState(
      rewardMode: rewardMode ?? this.rewardMode,
      useWalletBalance: useWalletBalance ?? this.useWalletBalance,
      brandDiscounts: brandDiscounts ?? this.brandDiscounts,
      brandDiscountsLoading: brandDiscountsLoading ?? this.brandDiscountsLoading,
      superCoinAuthorized: superCoinAuthorized ?? this.superCoinAuthorized,
      superCoinHoldContext: clearHold ? null : (superCoinHoldContext ?? this.superCoinHoldContext),
      superCoinOrderNumber: clearHold ? null : (superCoinOrderNumber ?? this.superCoinOrderNumber),
      superCoinCountdownSeconds: superCoinCountdownSeconds ?? this.superCoinCountdownSeconds,
      superCoinCountdownExpired: superCoinCountdownExpired ?? this.superCoinCountdownExpired,
      superCoinTransactionTime: clearHold ? null : (superCoinTransactionTime ?? this.superCoinTransactionTime),
      isProcessing: isProcessing ?? this.isProcessing,
      paymentError: clearError ? null : (paymentError ?? this.paymentError),
      paymentStatus: clearPaymentStatus ? null : (paymentStatus ?? this.paymentStatus),
    );
  }
}

// ── Checkout Notifier ──
class CartCheckoutNotifier extends StateNotifier<CartCheckoutState> {
  final SuperCoinApi _superCoinApi;
  Timer? _countdownTimer;

  CartCheckoutNotifier(this._superCoinApi) : super(const CartCheckoutState());

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Reward Mode ──
  void setRewardMode(RewardMode mode) {
    if (mode == RewardMode.superCoins) {
      state = state.copyWith(rewardMode: RewardMode.superCoins, useWalletBalance: false);
    } else {
      // Cancel supercoin hold when switching to cashback
      if (state.superCoinAuthorized) {
        cancelSuperCoinHold();
      }
      state = state.copyWith(
        rewardMode: RewardMode.cashbackWallet,
        superCoinAuthorized: false,
        superCoinHoldContext: null,
        superCoinOrderNumber: null,
        superCoinTransactionTime: null,
        superCoinCountdownSeconds: 900,
        superCoinCountdownExpired: false,
      );
    }
  }

  // ── Wallet ──
  void toggleWallet() {
    state = state.copyWith(useWalletBalance: !state.useWalletBalance);
  }

  // ── Brand Discounts ──
  Future<void> fetchBrandDiscounts(List<CartItem> cartItems, dynamic brandsApi) async {
    final uniqueBrandIds = cartItems.map((i) => i.brandId).toSet().toList();
    final unknownIds = uniqueBrandIds.where((id) => !state.brandDiscounts.containsKey(id)).toList();
    if (unknownIds.isEmpty) return;

    state = state.copyWith(brandDiscountsLoading: true);
    try {
      final results = await Future.wait(
        unknownIds.map((brandId) async {
          try {
            final brand = await brandsApi.getBrandById(brandId);
            final discount = double.tryParse(brand.discount ?? '0') ?? 0;
            return MapEntry(brandId, discount);
          } catch (_) {
            return MapEntry(brandId, 0.0);
          }
        }),
      );
      final updated = Map<String, double>.from(state.brandDiscounts);
      for (final entry in results) {
        updated[entry.key] = entry.value;
      }
      state = state.copyWith(brandDiscounts: updated, brandDiscountsLoading: false);
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
  }

  void _startCountdown(SuperCoinHoldContext holdContext) {
    _countdownTimer?.cancel();
    int remaining = 900;

    if (holdContext.transactionTime != null) {
      try {
        final startMs = DateTime.parse(holdContext.transactionTime!).millisecondsSinceEpoch;
        final endMs = startMs + 15 * 60 * 1000;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000).round().clamp(0, 900);
      } catch (_) {
        if (holdContext.stampExpiry != null) {
          remaining = ((holdContext.stampExpiry! - DateTime.now().millisecondsSinceEpoch) / 1000)
              .round()
              .clamp(0, 900);
        }
      }
    }

    state = state.copyWith(superCoinCountdownSeconds: remaining);

    if (remaining <= 0) {
      state = state.copyWith(superCoinCountdownExpired: true, superCoinAuthorized: false);
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.superCoinCountdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(
          superCoinCountdownSeconds: 0,
          superCoinCountdownExpired: true,
          superCoinAuthorized: false,
          superCoinHoldContext: null,
        );
      } else {
        state = state.copyWith(superCoinCountdownSeconds: next);
      }
    });
  }

  Future<void> cancelSuperCoinHold({String? orderNumber}) async {
    final holdContext = state.superCoinHoldContext;
    if (holdContext != null) {
      try {
        await _superCoinApi.unhold({
          'identity': {}, // Will be overridden by caller if needed
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

  void setPaymentError(String? error) {
    state = state.copyWith(paymentError: error, clearError: error == null);
  }

  void setPaymentStatus(String? status) {
    state = state.copyWith(paymentStatus: status, clearPaymentStatus: status == null);
  }

  void reset() {
    _countdownTimer?.cancel();
    state = const CartCheckoutState();
  }
}

// ── Providers ──
final cartCheckoutProvider =
    StateNotifierProvider.autoDispose<CartCheckoutNotifier, CartCheckoutState>((ref) {
  final superCoinApi = ref.watch(supercoinApiProvider);
  return CartCheckoutNotifier(superCoinApi);
});

// ── Derived Calculation Providers ──

/// Brand totals grouped by brand+unitValue
final brandTotalsProvider = Provider.autoDispose<Map<String, BrandTotal>>((ref) {
  final cart = ref.watch(cartProvider);
  final discounts = ref.watch(cartCheckoutProvider.select((s) => s.brandDiscounts));
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
  final double superCoinDeduction;
  final double finalPayable;
  final double cashbackPercent;
  final double cashbackAmount;
  final double maxSuperCoinRedeemable;
  final double estimatedEarn;

  const PaymentBreakdown({
    required this.subtotal,
    required this.processingFee,
    required this.couponDiscount,
    required this.couponAdjustedAmount,
    required this.walletDeduction,
    required this.superCoinDeduction,
    required this.finalPayable,
    required this.cashbackPercent,
    required this.cashbackAmount,
    required this.maxSuperCoinRedeemable,
    required this.estimatedEarn,
  });
}

final paymentBreakdownProvider = Provider.autoDispose<PaymentBreakdown>((ref) {
  final cart = ref.watch(cartProvider);
  final checkout = ref.watch(cartCheckoutProvider);
  final walletAsync = ref.watch(walletBalanceProvider);
  final superCoinState = ref.watch(supercoinProvider);

  final subtotal = cart?.totalAmount ?? 0;
  const processingFee = 0.0;
  const couponDiscount = 0.0; // Coupon hidden for now

  final couponAdjustedAmount = subtotal + processingFee - couponDiscount;

  // Wallet
  final walletBalance = (walletAsync.value?.totalBalance ?? 0).toDouble();
  final maxWalletUsage = subtotal * 0.5;
  final walletDeduction =
      checkout.useWalletBalance ? (walletBalance < maxWalletUsage ? walletBalance : maxWalletUsage) : 0.0;

  // SuperCoin — max redeemable = sum of each item's discount value
  // e.g., discount=3 → 3 coins, 2 items with discount=3 → 6 coins
  double maxSuperCoinRedeemable = 0;
  if (cart != null && cart.items.isNotEmpty) {
    final discountsLoaded = cart.items.every(
      (item) => item.discount != null || checkout.brandDiscounts.containsKey(item.brandId),
    );

    if (discountsLoaded) {
      maxSuperCoinRedeemable = cart.items.fold(0.0, (sum, item) {
        final disc = item.discount ?? checkout.brandDiscounts[item.brandId] ?? 0.0;
        return sum + disc;  // discount value = max SuperCoins for that item
      });
    } else {
      maxSuperCoinRedeemable = superCoinState.balance;
    }
  }

  final superCoinDeduction = checkout.superCoinAuthorized &&
          checkout.superCoinHoldContext != null
      ? (checkout.superCoinHoldContext!.amount < maxSuperCoinRedeemable
          ? checkout.superCoinHoldContext!.amount
          : maxSuperCoinRedeemable)
      : 0.0;

  final finalPayable = (couponAdjustedAmount - walletDeduction - superCoinDeduction)
      .clamp(0.0, double.infinity).toDouble();

  // Cashback % (weighted average)
  double cashbackPercent = 0;
  if (cart != null && cart.items.isNotEmpty) {
    final totalLine = cart.items.fold(0.0, (s, i) => s + i.lineTotal);
    if (totalLine > 0) {
      cashbackPercent = cart.items.fold(0.0, (sum, item) {
        final disc = item.discount ?? checkout.brandDiscounts[item.brandId] ?? 0;
        return sum + (item.lineTotal / totalLine) * disc;
      });
    }
  }
  final cashbackAmount = finalPayable * (cashbackPercent / 100);
  final estimatedEarn = finalPayable * 0.01;

  return PaymentBreakdown(
    subtotal: subtotal,
    processingFee: processingFee,
    couponDiscount: couponDiscount,
    couponAdjustedAmount: couponAdjustedAmount,
    walletDeduction: walletDeduction,
    superCoinDeduction: superCoinDeduction,
    finalPayable: finalPayable,
    cashbackPercent: cashbackPercent,
    cashbackAmount: cashbackAmount,
    maxSuperCoinRedeemable: maxSuperCoinRedeemable,
    estimatedEarn: estimatedEarn,
  );
});
