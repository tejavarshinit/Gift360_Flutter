import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/data/supercoin_excluded_brands.dart';

final supercoinApiProvider = Provider<SuperCoinApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return SuperCoinApi(dio);
});

/// SuperCoin configuration fetched from the backend (POST /v1/supercoin/config).
/// Mirrors React's `SuperCoinConfigResponse`: the rules live in the DB
/// (giftvouchers_brands row + application defaults), so a SQL update changes
/// behaviour without an app redeploy. The 20% cap fallback matches React.
class SuperCoinConfig {
  /// Max % of a voucher's face value coverable by SuperCoins.
  final double capPercent;

  /// Coins required per rupee of voucher value (1.25 UAT / 1.00 prod).
  final double burnRatio;

  /// Surcharge behind [burnRatio] (burnRatio == 1 + surchargePercent/100).
  final double surchargePercent;

  /// % coinback on burn orders for the special SKU (fallback 5).
  final double earnPercentSpecialSku;

  const SuperCoinConfig({
    required this.capPercent,
    this.burnRatio = 1.0,
    this.surchargePercent = 0,
    this.earnPercentSpecialSku = 5,
  });
}

double _configDouble(dynamic raw, double fallback) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? fallback;
}

final superCoinConfigProvider = FutureProvider<SuperCoinConfig>((ref) async {
  final api = ref.watch(supercoinApiProvider);
  final envRatio = SuperCoinConversionConfig.burnRatio;
  const fallbackCapPercent = 20.0;
  try {
    final response = await api.fetchConfig();
    final rawCap = response['capPercent'];
    final cap = rawCap is num && rawCap > 0
        ? rawCap.toDouble()
        : fallbackCapPercent;
    final rawRatio = response['burnRatio'];
    final ratio = rawRatio is num ? rawRatio.toDouble() : envRatio;
    return SuperCoinConfig(
      capPercent: cap,
      burnRatio: ratio,
      surchargePercent: _configDouble(response['surchargePercent'], 0),
      earnPercentSpecialSku: _configDouble(
        response['earnPercentSpecialSku'],
        5,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Could not fetch SuperCoin config; using fallback: $error');
    debugPrintStack(stackTrace: stackTrace);
    return SuperCoinConfig(capPercent: fallbackCapPercent, burnRatio: envRatio);
  }
});

/// Live burn ratio (DB config, env fallback) — used by the convert flow.
final superCoinBurnRatioProvider = Provider<double>((ref) {
  final config = ref.watch(superCoinConfigProvider).valueOrNull;
  return config?.burnRatio ?? SuperCoinConversionConfig.burnRatio;
});

/// Per-brand SuperCoin share percent (GET /v1/supercoin/brand-shares, V51).
/// 0 = cash only, 1..99 = that percent may be paid in SuperCoins, 100 = SC only.
final superCoinBrandSharesProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  try {
    return await ref.watch(supercoinApiProvider).fetchBrandShares();
  } catch (_) {
    return const <String, double>{};
  }
});

/// Brands shown in the convert modal and their pay mode (GET /v1/supercoin/modal-brands).
final superCoinModalBrandsProvider = FutureProvider<List<SuperCoinModalBrand>>((
  ref,
) async {
  try {
    return await ref.watch(supercoinApiProvider).fetchModalBrands();
  } catch (_) {
    return const <SuperCoinModalBrand>[];
  }
});

/// Per-brand cap override: a share in (0, 100) replaces the global cap percent.
double? superCoinCapShare(Map<String, double> shares, String brandId) {
  final share = shares[brandId];
  return (share != null && share > 0 && share < 100) ? share : null;
}

/// Share-aware exclusion, matching React Cart's `isScExcluded`: a brand with a
/// share < 100 is excluded only when the share is 0; otherwise the built-in
/// exclusion list applies.
bool isSuperCoinExcludedWithShares(
  Map<String, double> shares, {
  required String brandId,
  required String brandName,
}) {
  final share = shares[brandId];
  if (share != null && share < 100) return share <= 0;
  return !isSuperCoinEligible(brandId: brandId, brandName: brandName);
}

/// Normalize a mobile number to E.164 (matches React's normalizeMobileToE164).
/// Strips non-digits, prepends +91 to 10-digit, normalizes +91…, keeps +country.
String? normalizeMobileToE164(String? mobile) {
  if (mobile == null || mobile.trim().isEmpty) return null;
  final trimmed = mobile.trim();
  final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('+') && digitsOnly.length >= 10) return '+$digitsOnly';
  if (digitsOnly.length == 10) return '+91$digitsOnly';
  if (digitsOnly.length == 12 && digitsOnly.startsWith('91'))
    return '+$digitsOnly';
  return trimmed.startsWith('+')
      ? trimmed
      : '+${digitsOnly.isNotEmpty ? digitsOnly : trimmed}';
}

/// Extract the first finite balance value from a SuperCoin response.
/// Matches React's extractSuperCoinBalance().
double extractSuperCoinBalance(Map<String, dynamic> response) {
  for (final key in ['balance', 'totalBalance', 'availableBalance', 'amount']) {
    final val = response[key];
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

/// Burn ratio for converting rupees to SuperCoins (env fallback; prefer
/// [superCoinBurnRatioProvider] / config value which tracks the DB).
double get superCoinBurnRatio => SuperCoinConversionConfig.burnRatio;

/// Calculate the number of SuperCoins required to redeem a given rupee amount.
/// Formula: ceil(round(amount * burnRatio * 100) / 100) — matches React exactly.
int calculateSuperCoinsRequired(double voucherAmount, {double? burnRatio}) {
  final ratio = burnRatio ?? superCoinBurnRatio;
  final scaled = (voucherAmount * ratio * 100).round();
  return (scaled / 100).ceil();
}

/// Check if the user can afford a voucher with their SuperCoin balance.
/// Matches React's canAffordVoucher().
bool canAffordVoucher(
  double balance,
  double voucherAmount, {
  double? burnRatio,
}) {
  return balance >=
      calculateSuperCoinsRequired(voucherAmount, burnRatio: burnRatio);
}

// ── Hold Context ──
class SuperCoinHoldContext {
  final String merchantTransactionId;
  final String merchantWalletId;
  final double amount;
  final int? stampExpiry;
  final String? transactionTime;

  const SuperCoinHoldContext({
    required this.merchantTransactionId,
    required this.merchantWalletId,
    required this.amount,
    this.stampExpiry,
    this.transactionTime,
  });
}

// ── SuperCoin State ──
class SuperCoinState {
  final bool userExists;
  final bool isEnrolled;
  final double balance;
  final bool isBalanceLoading;
  final bool isSearching;
  final String? error;

  const SuperCoinState({
    this.userExists = false,
    this.isEnrolled = false,
    this.balance = 0,
    this.isBalanceLoading = false,
    this.isSearching = false,
    this.error,
  });

  SuperCoinState copyWith({
    bool? userExists,
    bool? isEnrolled,
    double? balance,
    bool? isBalanceLoading,
    bool? isSearching,
    String? error,
    bool clearError = false,
  }) {
    return SuperCoinState(
      userExists: userExists ?? this.userExists,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      balance: balance ?? this.balance,
      isBalanceLoading: isBalanceLoading ?? this.isBalanceLoading,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── SuperCoin Notifier ──
class SuperCoinNotifier extends StateNotifier<SuperCoinState> {
  final SuperCoinApi _api;
  final String? _mobile;
  final String? _clientId;

  SuperCoinNotifier(this._api, this._mobile, [this._clientId])
    : super(const SuperCoinState()) {
    if (_mobile != null && _mobile!.isNotEmpty) {
      _searchAndLoadBalance();
    }
  }

  String? _normalizeMobile(String? mobile) => normalizeMobileToE164(mobile);

  SuperCoinIdentity? get identity {
    final normalized = _normalizeMobile(_mobile);
    if (normalized == null) return null;
    return SuperCoinIdentity(identifier: normalized, type: 'MOBILE');
  }

  Future<void> _searchAndLoadBalance() async {
    final id = identity;
    if (id == null) return;

    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final searchResult = await _api.searchUser(id);
      final exists =
          searchResult['userExists'] == true ||
          (searchResult['state']?.toString().toUpperCase() == 'ACTIVATED');

      state = state.copyWith(
        userExists: exists,
        isEnrolled: exists,
        isSearching: false,
      );

      if (exists) {
        await fetchBalance();
      }
    } catch (e) {
      state = state.copyWith(isSearching: false, error: e.toString());
    }
  }

  Future<void> fetchBalance() async {
    final id = identity;
    if (id == null) return;

    state = state.copyWith(isBalanceLoading: true, clearError: true);
    try {
      final result = await _api.fetchBalance(id);
      final bal = extractSuperCoinBalance(result);
      state = state.copyWith(balance: bal, isBalanceLoading: false);
      final clientId = _clientId;
      if (clientId != null && clientId.isNotEmpty) {
        _api.syncBalance(clientId, bal);
      }
    } catch (e) {
      state = state.copyWith(isBalanceLoading: false, error: e.toString());
    }
  }

  /// Re-run the same account lookup sequence as React's SuperCoinStatusCard.
  /// This is called when the user explicitly opens the SuperCoins checkout tab,
  /// so an already-mounted cart cannot leave the account state stale.
  Future<void> refresh() async {
    await _searchAndLoadBalance();
  }

  void reset() {
    state = const SuperCoinState();
  }
}

final supercoinProvider =
    StateNotifierProvider.autoDispose<SuperCoinNotifier, SuperCoinState>((ref) {
      final api = ref.watch(supercoinApiProvider);
      final user = ref.watch(authProvider);
      return SuperCoinNotifier(api, user?.mobile, user?.clientId);
    });

// ── OTP Modal State ──
enum SuperCoinOtpStep { loadingBalance, ready, otpSent, authorized }

class SuperCoinOtpState {
  final SuperCoinOtpStep step;
  final double balance;
  final double coinAmount;
  final String otp;
  final String prefilledOtp;
  final String merchantTransactionId;
  final String? error;
  final bool isLoading;
  final String? transactionTime;
  final int countdownSeconds;
  final bool countdownExpired;
  final int? holdExpiryMs;

  const SuperCoinOtpState({
    this.step = SuperCoinOtpStep.loadingBalance,
    this.balance = 0,
    this.coinAmount = 0,
    this.otp = '',
    this.prefilledOtp = '',
    this.merchantTransactionId = '',
    this.error,
    this.isLoading = false,
    this.transactionTime,
    this.countdownSeconds = 900,
    this.countdownExpired = false,
    this.holdExpiryMs,
  });

  SuperCoinOtpState copyWith({
    SuperCoinOtpStep? step,
    double? balance,
    double? coinAmount,
    String? otp,
    String? prefilledOtp,
    String? merchantTransactionId,
    String? error,
    bool? isLoading,
    String? transactionTime,
    int? countdownSeconds,
    bool? countdownExpired,
    int? holdExpiryMs,
    bool clearError = false,
  }) {
    return SuperCoinOtpState(
      step: step ?? this.step,
      balance: balance ?? this.balance,
      coinAmount: coinAmount ?? this.coinAmount,
      otp: otp ?? this.otp,
      prefilledOtp: prefilledOtp ?? this.prefilledOtp,
      merchantTransactionId:
          merchantTransactionId ?? this.merchantTransactionId,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      transactionTime: transactionTime ?? this.transactionTime,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      countdownExpired: countdownExpired ?? this.countdownExpired,
      holdExpiryMs: holdExpiryMs ?? this.holdExpiryMs,
    );
  }
}

class SuperCoinOtpNotifier extends StateNotifier<SuperCoinOtpState> {
  final SuperCoinApi _api;
  final SuperCoinIdentity? _identity;
  final String _merchantWalletId;
  final String _orderNumber;
  final String _displayName;
  final double _preloadedBalance;
  final double _maxRedeemable;

  Timer? _countdownTimer;

  SuperCoinOtpNotifier({
    required SuperCoinApi api,
    required SuperCoinIdentity? identity,
    required String merchantWalletId,
    required String orderNumber,
    required String displayName,
    required double preloadedBalance,
    required double maxRedeemable,
  }) : _api = api,
       _identity = identity,
       _merchantWalletId = merchantWalletId,
       _orderNumber = orderNumber,
       _displayName = displayName,
       _preloadedBalance = preloadedBalance,
       _maxRedeemable = maxRedeemable,
       super(
         SuperCoinOtpState(
           balance: preloadedBalance,
           coinAmount: _calculateCoinAmount(preloadedBalance, maxRedeemable),
         ),
       ) {
    _loadBalance();
  }

  static double _calculateCoinAmount(double balance, double maxRedeemable) {
    return maxRedeemable > 0
        ? (balance < maxRedeemable ? balance : maxRedeemable)
        : balance;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (_identity == null) {
      state = state.copyWith(step: SuperCoinOtpStep.ready, clearError: true);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.fetchBalance(_identity!);
      double bal = 0;
      for (final key in [
        'balance',
        'totalBalance',
        'availableBalance',
        'amount',
      ]) {
        final val = result[key];
        if (val is num) {
          bal = val.toDouble();
          break;
        }
      }
      final coinAmount = _calculateCoinAmount(bal, _maxRedeemable);
      state = state.copyWith(
        step: SuperCoinOtpStep.ready,
        balance: bal,
        coinAmount: coinAmount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load your SuperCoin balance. Please try again.',
      );
    }
  }

  Future<void> applyCoins() async {
    if (_identity == null) {
      state = state.copyWith(error: 'SuperCoin identity not available.');
      return;
    }
    if (_merchantWalletId.isEmpty) {
      state = state.copyWith(
        error: 'SuperCoin merchant wallet is not configured.',
      );
      return;
    }
    if (_orderNumber.trim().isEmpty) {
      state = state.copyWith(
        error: 'Order is not ready yet. Please try again.',
      );
      return;
    }

    final txnId = '${_orderNumber}-SC';
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      merchantTransactionId: txnId,
    );
    try {
      final response = await _api.initHold({
        'identity': _identity!.toJson(),
        'merchantWalletId': _merchantWalletId,
        'merchantTransactionId': txnId,
        'merchantReferenceId': _orderNumber,
        'amount': state.coinAmount,
        'displayName': _displayName,
        'stampExpiry': DateTime.now().millisecondsSinceEpoch + 15 * 60 * 1000,
      });

      String? otp;
      if (response['otp'] != null) otp = response['otp'].toString();
      final txTime = response['transactionTime'] as String?;
      int holdExpiry = DateTime.now().millisecondsSinceEpoch + 15 * 60 * 1000;
      if (response['stampExpiry'] is num) {
        holdExpiry = (response['stampExpiry'] as num).toInt();
      }

      state = state.copyWith(
        step: SuperCoinOtpStep.otpSent,
        isLoading: false,
        prefilledOtp: otp ?? '',
        otp: otp ?? '',
        transactionTime: txTime,
        holdExpiryMs: holdExpiry,
      );

      _startCountdown(txTime, holdExpiry);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().contains('Exception')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Failed to initiate SuperCoin hold. Please try again.',
      );
    }
  }

  void _startCountdown(String? txTime, int holdExpiryMs) {
    _countdownTimer?.cancel();
    int remaining = 900; // 15 minutes default

    if (txTime != null) {
      try {
        final startMs = DateTime.parse(txTime).millisecondsSinceEpoch;
        final endMs = startMs + 15 * 60 * 1000;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .round()
            .clamp(0, 900);
      } catch (_) {
        final endMs = holdExpiryMs;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .round()
            .clamp(0, 900);
      }
    }

    state = state.copyWith(
      countdownSeconds: remaining,
      countdownExpired: remaining <= 0,
    );

    if (remaining <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.countdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(countdownSeconds: 0, countdownExpired: true);
        reset();
      } else {
        state = state.copyWith(countdownSeconds: next);
      }
    });
  }

  void updateOtp(String value) {
    state = state.copyWith(otp: value);
  }

  Future<SuperCoinHoldContext?> verifyOtp() async {
    if (state.otp.trim().length < 6) {
      state = state.copyWith(error: 'Please enter a valid 6-digit OTP.');
      return null;
    }
    if (state.merchantTransactionId.isEmpty || _merchantWalletId.isEmpty) {
      state = state.copyWith(
        error: 'Missing transaction context. Please start over.',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.authorizeHold({
        'identity': _identity!.toJson(),
        'merchantWalletId': _merchantWalletId,
        'merchantTransactionId': state.merchantTransactionId,
        'otp': state.otp.trim(),
      });

      final txnState = response['transactionState']?.toString().toUpperCase();
      if (txnState == 'SUCCESSFUL' || txnState == 'SUCCESS') {
        _countdownTimer?.cancel();
        state = state.copyWith(
          step: SuperCoinOtpStep.authorized,
          isLoading: false,
        );
        final holdContext = SuperCoinHoldContext(
          merchantTransactionId: state.merchantTransactionId,
          merchantWalletId: _merchantWalletId,
          amount: state.coinAmount,
          stampExpiry: state.holdExpiryMs,
          transactionTime: state.transactionTime,
        );
        // Persist hold context to survive gateway redirect (matches React sessionStorage)
        await _persistHoldContext(holdContext);
        return holdContext;
      } else {
        state = state.copyWith(
          isLoading: false,
          error:
              response['message']?.toString() ??
              'OTP verification failed. Please try again.',
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().contains('Exception')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'OTP verification failed. Please try again.',
      );
      return null;
    }
  }

  void reset() {
    _countdownTimer?.cancel();
    state = SuperCoinOtpState(
      balance: _preloadedBalance,
      coinAmount: _calculateCoinAmount(_preloadedBalance, _maxRedeemable),
    );
  }

  /// Persist SuperCoin hold context to SharedPreferences (mirrors React sessionStorage).
  Future<void> _persistHoldContext(SuperCoinHoldContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'merchantTransactionId': context.merchantTransactionId,
        'merchantWalletId': context.merchantWalletId,
        'amount': context.amount,
        'stampExpiry': context.stampExpiry,
        'transactionTime': context.transactionTime,
      };
      await prefs.setString('superCoinHold_${_orderNumber}', jsonEncode(data));
    } catch (_) {}
  }

  /// Persist a SuperCoin hold context to SharedPreferences keyed by order number.
  static Future<void> persistHoldContext(
    String orderNumber,
    SuperCoinHoldContext context,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'merchantTransactionId': context.merchantTransactionId,
        'merchantWalletId': context.merchantWalletId,
        'amount': context.amount,
        'stampExpiry': context.stampExpiry,
        'transactionTime': context.transactionTime,
      };
      await prefs.setString('superCoinHold_$orderNumber', jsonEncode(data));
    } catch (_) {}
  }

  /// Load persisted SuperCoin hold context from SharedPreferences.
  static Future<SuperCoinHoldContext?> loadHoldContext(
    String orderNumber,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('superCoinHold_$orderNumber');
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return SuperCoinHoldContext(
        merchantTransactionId: data['merchantTransactionId'] as String? ?? '',
        merchantWalletId: data['merchantWalletId'] as String? ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        stampExpiry: data['stampExpiry'] as int?,
        transactionTime: data['transactionTime'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clear persisted SuperCoin hold context.
  static Future<void> clearHoldContext(String orderNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('superCoinHold_$orderNumber');
    } catch (_) {}
  }

  // ── Active order number persistence (rehydration on cold start) ──

  /// Persist the active order number that has a SuperCoin hold, so the
  /// cart screen can rehydrate the hold on cold start (matches React's
  /// sessionStorage persistence of superCoinOrderNumber).
  static Future<void> persistActiveOrderNumber(String orderNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeSuperCoinOrderNumber', orderNumber);
    } catch (_) {}
  }

  /// Load the active order number that has a SuperCoin hold.
  static Future<String?> loadActiveOrderNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('activeSuperCoinOrderNumber');
    } catch (_) {
      return null;
    }
  }

  /// Clear the active order number (after hold is consumed or cancelled).
  static Future<void> clearActiveOrderNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('activeSuperCoinOrderNumber');
    } catch (_) {}
  }
}

final superCoinOtpProvider =
    StateNotifierProvider.autoDispose<SuperCoinOtpNotifier, SuperCoinOtpState>(
      (ref) => throw UnimplementedError('Override in widget'),
    );
