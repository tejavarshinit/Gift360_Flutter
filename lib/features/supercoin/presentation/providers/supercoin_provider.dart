import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';

final supercoinApiProvider = Provider<SuperCoinApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return SuperCoinApi(dio);
});

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

  SuperCoinNotifier(this._api, this._mobile) : super(const SuperCoinState()) {
    if (_mobile != null && _mobile!.isNotEmpty) {
      _searchAndLoadBalance();
    }
  }

  String? _normalizeMobile(String? mobile) {
    if (mobile == null || mobile.trim().isEmpty) return null;
    final trimmed = mobile.trim();
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('+') && digitsOnly.length >= 10) return '+$digitsOnly';
    if (digitsOnly.length == 10) return '+91$digitsOnly';
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) return '+$digitsOnly';
    return trimmed.startsWith('+') ? trimmed : '+${digitsOnly.isNotEmpty ? digitsOnly : trimmed}';
  }

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
      final exists = searchResult['userExists'] == true ||
          (searchResult['state']?.toString().toUpperCase() == 'ACTIVATED');

      state = state.copyWith(userExists: exists, isEnrolled: exists, isSearching: false);

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
      final bal = _extractBalance(result);
      state = state.copyWith(balance: bal, isBalanceLoading: false);
    } catch (e) {
      state = state.copyWith(isBalanceLoading: false, error: e.toString());
    }
  }

  double _extractBalance(Map<String, dynamic> response) {
    for (final key in ['balance', 'totalBalance', 'availableBalance', 'amount']) {
      final val = response[key];
      if (val is num) return val.toDouble();
    }
    return 0;
  }

  void reset() {
    state = const SuperCoinState();
  }
}

final supercoinProvider =
    StateNotifierProvider.autoDispose<SuperCoinNotifier, SuperCoinState>((ref) {
  final api = ref.watch(supercoinApiProvider);
  final user = ref.watch(authProvider);
  return SuperCoinNotifier(api, user?.mobile);
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
      merchantTransactionId: merchantTransactionId ?? this.merchantTransactionId,
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
  })  : _api = api,
        _identity = identity,
        _merchantWalletId = merchantWalletId,
        _orderNumber = orderNumber,
        _displayName = displayName,
        _preloadedBalance = preloadedBalance,
        _maxRedeemable = maxRedeemable,
        super(SuperCoinOtpState(
          balance: preloadedBalance,
          coinAmount: _calculateCoinAmount(preloadedBalance, maxRedeemable),
        )) {
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
      for (final key in ['balance', 'totalBalance', 'availableBalance', 'amount']) {
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
      state = state.copyWith(error: 'SuperCoin merchant wallet is not configured.');
      return;
    }
    if (_orderNumber.trim().isEmpty) {
      state = state.copyWith(error: 'Order is not ready yet. Please try again.');
      return;
    }

    final txnId = '${_orderNumber}-SC';
    state = state.copyWith(isLoading: true, clearError: true, merchantTransactionId: txnId);
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
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000).round().clamp(0, 900);
      } catch (_) {
        final endMs = holdExpiryMs;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000).round().clamp(0, 900);
      }
    }

    state = state.copyWith(countdownSeconds: remaining, countdownExpired: remaining <= 0);

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
      state = state.copyWith(error: 'Missing transaction context. Please start over.');
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
        state = state.copyWith(step: SuperCoinOtpStep.authorized, isLoading: false);
        return SuperCoinHoldContext(
          merchantTransactionId: state.merchantTransactionId,
          merchantWalletId: _merchantWalletId,
          amount: state.coinAmount,
          stampExpiry: state.holdExpiryMs,
          transactionTime: state.transactionTime,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['message']?.toString() ?? 'OTP verification failed. Please try again.',
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
}

final superCoinOtpProvider = StateNotifierProvider.autoDispose<SuperCoinOtpNotifier, SuperCoinOtpState>(
  (ref) => throw UnimplementedError('Override in widget'),
);
