import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gift360/config/app_config.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_checkout_provider.dart';
import 'package:gift360/features/cart/presentation/widgets/supercoin_otp_modal.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/presentation/widgets/supercoin_expiry_card.dart';
import 'package:gift360/features/order/presentation/providers/order_provider.dart';

/// Port of React `src/components/SuperCoinsBrandModal.tsx` — the
/// "Convert SuperCoins to a gift voucher" flow. Opened via the route
/// `/supercoin-voucher` (matches React's `/supercoin-voucher` page) with
/// the featured brand id.
class SuperCoinBrandModal extends ConsumerStatefulWidget {
  final bool open;
  final String brandId;
  final VoidCallback onClose;

  const SuperCoinBrandModal({
    super.key,
    required this.open,
    required this.brandId,
    required this.onClose,
  });

  @override
  ConsumerState<SuperCoinBrandModal> createState() => _SuperCoinBrandModalState();
}

class _SuperCoinBrandModalState extends ConsumerState<SuperCoinBrandModal> {
  String _selectedBrandId = '';
  Brand? _brand;
  bool _brandLoading = true;
  String? _brandError;

  /// One-time DB modal-brand selection (React picks the first DB brand, or the
  /// featured Flipkart brand when that one is SC_ONLY / featured).
  bool _modalBrandsInitialized = false;

  int _amount = 0;
  int _quantity = 1;
  int? _activeTab; // 0 about, 1 how, 2 terms

  // SuperCoin state
  bool _superCoinAuthorized = false;
  SuperCoinHoldContext? _superCoinHoldContext;
  Timer? _countdownTimer;
  int _countdownSeconds = 900;
  bool _countdownExpired = false;
  String? _transactionTime;

  bool _superCoinOtpModalOpen = false;
  bool _burnSuccess = false;
  bool _burnError = false;
  String _burnErrorTitle = '';
  String _burnErrorDescription = '';
  double? _burnErrorBalance;
  Map<String, dynamic>? _burnResultData;
  int? _orderDetailsCoinsEarned;
  bool _orderDetailsLoading = false;

  bool _isBurning = false;
  bool _isCreatingOrder = false;

  String _orderNumber = '';

  @override
  void initState() {
    super.initState();
    _selectedBrandId = widget.brandId;
    _loadBrand();
    if (widget.open) _resetState();
  }

  @override
  void didUpdateWidget(covariant SuperCoinBrandModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.brandId != oldWidget.brandId) {
      setState(() => _selectedBrandId = widget.brandId);
      _loadBrand();
    }
    if (widget.open && !oldWidget.open) {
      _resetState();
      // Re-trigger balance load
      setState(() {});
    }
  }

  Future<void> _loadBrand() async {
    setState(() {
      _brandLoading = true;
      _brandError = null;
    });
    try {
      final api = ref.read(brandsApiProvider);
      final details = await api.getBrandDetailsById(_selectedBrandId);
      if (!mounted) return;
      setState(() {
        _brand = details;
        _brandLoading = false;
      });
      _initAmount(details);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _brandError = e.toString();
        _brandLoading = false;
      });
    }
  }

  void _initAmount(Brand brand) {
    final isFixed = (brand.brandType ?? '').toLowerCase() == 'fixed';
    if (isFixed) {
      final list = _parseDenomList(brand.denominationList);
      if (list.isNotEmpty) {
        setState(() => _amount = list.first.toInt());
        return;
      }
    }
    final min = brand.minPrice ?? 0;
    if (min > 0) setState(() => _amount = min.toInt());
  }

  List<double> _parseDenomList(String? source) {
    if (source == null || source.isEmpty) return [];
    return source
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }

  void _resetState() {
    _amount = 0;
    _quantity = 1;
    _superCoinAuthorized = false;
    _superCoinHoldContext = null;
    _countdownTimer?.cancel();
    _countdownSeconds = 900;
    _countdownExpired = false;
    _transactionTime = null;
    _burnSuccess = false;
    _burnError = false;
    _burnResultData = null;
    _orderDetailsCoinsEarned = null;
    _orderDetailsLoading = false;
    _isBurning = false;
    _isCreatingOrder = false;
    _orderNumber = '';
    _activeTab = 0;
  }

  // ─── Computed ───
  double get _min {
    final b = _brand;
    if (b == null) return 0;
    if ((b.minPrice ?? 0) > 0) return b.minPrice!;
    final list = _parseDenomList(b.denominationList);
    if (list.isNotEmpty) return list.first;
    return 0;
  }

  double get _max {
    final b = _brand;
    if (b == null) return 0;
    if ((b.maxPrice ?? 0) > 0) return b.maxPrice!;
    final list = _parseDenomList(b.denominationList);
    if (list.isNotEmpty) return list.last;
    return _min;
  }

  bool get _isFixedType =>
      (_brand?.brandType ?? '').toLowerCase() == 'fixed';

  int get _discountPercent => int.tryParse(_brand?.discount ?? '') ?? 0;

  double get _totalVoucherValue => _amount.toDouble() * _quantity;

  int get _superCoinsRequired => calculateSuperCoinsRequired(
        _totalVoucherValue,
        burnRatio: ref.watch(superCoinConfigProvider).valueOrNull?.burnRatio ??
            SuperCoinConversionConfig.burnRatio,
      );

  bool get _isAmountValid => _amount >= _min && _amount <= _max && _amount > 0;

  /// Earn % for the special SKU, read live from the backend config
  /// (fallback 5, matching React FALLBACK_SUPERCOIN_EARN_PERCENT).
  double get _earnPercent =>
      ref.watch(superCoinConfigProvider).valueOrNull?.earnPercentSpecialSku ?? 5.0;

  static const List<String> _earnSkus = ['EGCGBFKC002', 'EGCGBFKSCR001'];

  bool get _isFivePercentEarnSku =>
      _earnSkus.contains((_brand?.brandCode ?? '').trim().toUpperCase());

  bool get _qualifiesForEarn => _isFivePercentEarnSku && _amount >= 100;

  bool get _showEarnThreshold =>
      _isFivePercentEarnSku && _isAmountValid && _amount > 0 && !_qualifiesForEarn;

  double get _superCoinsEarnPotential {
    if (!_qualifiesForEarn) return 0;
    final earn = _totalVoucherValue * (_earnPercent / 100);
    return (earn < 100 ? earn : 100);
  }

  bool _hasEnoughCoins(double balance) =>
      _isAmountValid && balance >= _superCoinsRequired;

  String _normalizeMobile(String? m) => normalizeMobileToE164(m) ?? '';

  String get _normalizeBrandCode => (_brand?.brandCode ?? '').trim().toUpperCase();

  SuperCoinIdentity? get _superCoinIdentity {
    final user = ref.read(authProvider);
    final nm = _normalizeMobile(user?.mobile);
    if (nm.isEmpty) return null;
    return SuperCoinIdentity(identifier: nm, type: 'MOBILE');
  }

  String _formatCurrency(double value) => '\u20b9${value.toStringAsFixed(0)}';

  // ── Order creation + OTP open ──
  Future<void> _openSuperCoinFlow() async {
    final user = ref.read(authProvider);
    final brand = _brand;
    final identity = _superCoinIdentity;
    if (identity == null || user == null || brand == null || !_isAmountValid) return;
    if (_isCreatingOrder || _isBurning) return;

    final today = DateTime.now();
    final yymmdd =
        '${today.year.toString().substring(2)}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final rng = Random.secure();
    final uuid = List.generate(12, (_) => rng.nextInt(16).toRadixString(16)).join().toUpperCase();
    final newOrderNumber = 'ORD$yymmdd$uuid';

    final orderRequest = {
      'order': {
        'clientId': user.clientId,
        'orderNumber': newOrderNumber,
        'totalAmount': _totalVoucherValue,
        'currency': 'INR',
        'status': 'PENDING',
        'walletUsed': false,
        'walletAmount': 0,
        'earnCashback': false,
        'paymentMethod': 'SUPERCOIN',
      },
      'items': [
        {
          'brandId': brand.brandId ?? '',
          'quantity': _quantity,
          'unitValue': _amount.toDouble(),
          'lineTotal': _totalVoucherValue,
          'meta': jsonEncode({
            'brand_name': brand.brandName,
            'brand_code': brand.brandCode,
            'brandId': brand.brandId,
            'image_url': brand.resolvedImageUrl,
            'redeem_steps': (brand.howToUse ?? '').split('\n').where((s) => s.trim().isNotEmpty).toList(),
          }),
        },
      ],
    };

    setState(() => _isCreatingOrder = true);
    try {
      final api = ref.read(orderApiProvider);
      final response = await api.createOrder(orderRequest);
      final returned = response['orderNumber']?.toString() ?? newOrderNumber;
      if (!mounted) return;
      setState(() {
        _orderNumber = returned;
        _isCreatingOrder = false;
      });
      _superCoinOtpModalOpen = true;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start: ${e.toString()}')),
      );
    }
  }

  void _startCountdown(SuperCoinHoldContext ctx) {
    _countdownTimer?.cancel();
    int remaining = 900;
    if (ctx.transactionTime != null) {
      try {
        final startMs = DateTime.parse(ctx.transactionTime!).millisecondsSinceEpoch;
        final endMs = startMs + 15 * 60 * 1000;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000).round().clamp(0, 900);
      } catch (_) {}
    }
    setState(() {
      _countdownSeconds = remaining;
      _countdownExpired = remaining <= 0;
    });
    if (remaining <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _countdownSeconds - 1;
      if (next <= 0) {
        t.cancel();
        setState(() {
          _countdownSeconds = 0;
          _countdownExpired = true;
          _superCoinAuthorized = false;
          _superCoinHoldContext = null;
        });
      } else {
        setState(() => _countdownSeconds = next);
      }
    });
  }

  Future<void> _handleClose() async {
    final holdContext = _superCoinHoldContext;
    if (holdContext != null && _superCoinIdentity != null) {
      try {
        final scApi = ref.read(supercoinApiProvider);
        await scApi.unhold({
          'identity': _superCoinIdentity!.toJson(),
          'merchantTransactionId': holdContext.merchantTransactionId,
          'merchantWalletId': holdContext.merchantWalletId,
        });
      } catch (_) {}
    }
    _superCoinHoldContext = null;
    _superCoinAuthorized = false;
    widget.onClose();
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handleBurnComplete(SuperCoinHoldContext context) async {
    final user = ref.read(authProvider);
    final brand = _brand;
    final identity = _superCoinIdentity;
    if (identity == null || _orderNumber.isEmpty || user == null || brand == null) return;

    setState(() => _isBurning = true);
    try {
      final scApi = ref.read(supercoinApiProvider);
      final result = await scApi.burnAndOrder({
        'orderNumber': _orderNumber,
        'displayName': brand.brandName ?? 'Gift360 Voucher',
        'amount': _totalVoucherValue,
        'clientId': user.clientId,
      });

      final success = result['success'];
      if (success == false) {
        final code = result['errorCode']?.toString();
        setState(() {
          _isBurning = false;
          _burnError = true;
          _burnErrorTitle = code == 'VOUCHER_CONVERSION_FAILED'
              ? 'Voucher conversion failed'
              : code == 'COIN_REDEEM_FAILED'
                  ? 'SuperCoin redemption failed'
                  : 'Conversion failed';
          _burnErrorDescription = code == 'VOUCHER_CONVERSION_FAILED'
              ? 'Your coins have been refunded.'
              : (result['message']?.toString() ??
                  result['error']?.toString() ??
                  'SuperCoin conversion was not successful. Please try again.');
          _burnErrorBalance = (result['balance'] is num)
              ? (result['balance'] as num).toDouble()
              : null;
        });
        if (code == 'VOUCHER_CONVERSION_FAILED') {
          setState(() {
            _superCoinAuthorized = false;
            _superCoinHoldContext = null;
          });
        }
        return;
      }

      setState(() {
        _superCoinOtpModalOpen = false;
        _burnSuccess = true;
        _burnResultData = {
          'coinsRedeemed': result['coinsRedeemed'],
          'coinsEarned': result['coinsEarned'],
          'balance': result['balance'],
        };
        _isBurning = false;
      });

      // Fetch order details + fresh balance
      setState(() => _orderDetailsLoading = true);
      try {
        final orderApi = ref.read(orderApiProvider);
        final details = await orderApi.fetchOrderDetails(_orderNumber);
        final balRes = await scApi.fetchBalance(identity);
        final freshBalance = (balRes['balance'] is num)
            ? (balRes['balance'] as num).toDouble()
            : (balRes['totalBalance'] is num ? (balRes['totalBalance'] as num).toDouble() : null);
        setState(() {
          _orderDetailsCoinsEarned = (details['coinsEarned'] is num)
              ? (details['coinsEarned'] as num).toInt()
              : (result['coinsEarned'] is num ? (result['coinsEarned'] as num).toInt() : null);
          _burnResultData = {
            'coinsRedeemed': details['coinsRedeemed'] ?? result['coinsRedeemed'],
            'coinsEarned': details['coinsEarned'] ?? result['coinsEarned'],
            'balance': freshBalance ?? _burnResultData?['balance'],
          };
          _orderDetailsLoading = false;
        });
      } catch (_) {
        setState(() => _orderDetailsLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      final fallbackBalance = ref.read(supercoinProvider).balance;
      setState(() {
        _isBurning = false;
        _burnError = true;
        _burnErrorTitle = 'Conversion failed';
        _burnErrorDescription = (e.toString().contains('500'))
            ? 'Voucher conversion failed. Coins refunded.'
            : 'Failed to complete SuperCoin conversion. Please try again.';
        _burnErrorBalance = fallbackBalance;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final user = ref.watch(authProvider);
    final scState = ref.watch(supercoinProvider);
    final balance = (scState.balance > 0 ? scState.balance : (_burnResultData?['balance'] ?? 0).toDouble());
    final hasEnough = _hasEnoughCoins(scState.balance);
    final modalBrands =
        ref.watch(superCoinModalBrandsProvider).valueOrNull ?? const <SuperCoinModalBrand>[];
    // Keep brand shares hot so split-pay state is available in the body.
    ref.watch(superCoinBrandSharesProvider);

    // One-time: open on the DB's first brand (featured Flipkart brand when the
    // first entry is SC_ONLY / is the featured brand), matching React.
    if (!_modalBrandsInitialized && modalBrands.isNotEmpty) {
      _modalBrandsInitialized = true;
      final first = modalBrands.first;
      final next = (first.payMode.toUpperCase() == 'SC_ONLY' ||
              first.brandId == SuperCoinConversionConfig.featuredBrandId)
          ? SuperCoinConversionConfig.featuredBrandId
          : first.brandId;
      if (next != _selectedBrandId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedBrandId = next);
          _loadBrand();
        });
      }
    }

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _handleClose(),
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        // Sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 390),
            margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0 + 63),
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: 600,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 50,
                      offset: const Offset(0, -18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildBody(user, scState, balance, hasEnough)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_superCoinOtpModalOpen && _superCoinIdentity != null)
          SuperCoinOTPModal(
            merchantWalletId: AppConfig.supercoinMerchantWalletId,
            orderNumber: _orderNumber,
            displayName: _brand?.brandName ?? 'Gift360 SuperCoin',
            preloadedBalance: scState.balance,
            maxRedeemable: _superCoinsRequired.toDouble(),
            onAuthorized: (ctx) {
              _superCoinHoldContext = ctx;
              _superCoinAuthorized = true;
              _superCoinOtpModalOpen = false;
              _transactionTime = ctx.transactionTime ??
                  DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String();
              _startCountdown(ctx);
              setState(() {});
              _handleBurnComplete(ctx);
            },
            onSwitchToCashback: () {
              _superCoinOtpModalOpen = false;
              _orderNumber = '';
              setState(() {});
            },
            onClose: () => setState(() => _superCoinOtpModalOpen = false),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9747FF), Color(0xFF7C3AED), Color(0xFF5B2B99)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _handleClose(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SUPERCOINS',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                        color: const Color(0xFFF7D46B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _brand?.brandName ?? 'Loading brand...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // X close button — returns to the previous flow (onClose pops
              // back, or goes home when there is nothing to pop).
              GestureDetector(
                onTap: () => _handleClose(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Brand selector chips, driven by the DB (supercoin_modal_order).
          // Falls back to the featured-voucher pill when the list is empty.
          SizedBox(
            height: 28,
            child: Builder(builder: (context) {
              final brands =
                  ref.watch(superCoinModalBrandsProvider).valueOrNull ?? const <SuperCoinModalBrand>[];
              if (brands.isEmpty) {
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'SuperCoin E-Gift Voucher',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: brands.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, index) {
                  final b = brands[index];
                  final selected = b.brandId == _selectedBrandId;
                  return GestureDetector(
                    onTap: selected
                        ? null
                        : () {
                            setState(() => _selectedBrandId = b.brandId);
                            _loadBrand();
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: selected ? 0 : 0.35)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            b.brandName.isEmpty ? b.brandCode : b.brandName,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: selected ? const Color(0xFF7C3AED) : Colors.white,
                            ),
                          ),
                          if (b.isCashEarn) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7D46B),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Cash+Coins',
                                  style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF5B2B99))),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(dynamic user, SuperCoinState scState, double balance, bool hasEnough) {
    if (_brandLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF9747FF)));
    }
    if (_brandError != null || _brand == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load brand', style: GoogleFonts.poppins(color: const Color(0xFF6B7280))),
        ),
      );
    }
    if (_burnSuccess) return _buildSuccessUI(scState, balance);
    if (_burnError) return _buildErrorUI(balance);

    final brand = _brand!;
    final isFixed = _isFixedType;
    final denomList = _parseDenomList(brand.denominationList);

    // DB modal-brand pay mode + per-brand split share (V47/V51).
    final modalBrands =
        ref.watch(superCoinModalBrandsProvider).valueOrNull ?? const <SuperCoinModalBrand>[];
    SuperCoinModalBrand? selectedModalBrand;
    for (final b in modalBrands) {
      if (b.brandId == _selectedBrandId) {
        selectedModalBrand = b;
        break;
      }
    }
    final isCashEarn = selectedModalBrand?.isCashEarn ?? false;
    final cashEarnPercent = selectedModalBrand?.earnPercent ?? 0.0;
    final shares =
        ref.watch(superCoinBrandSharesProvider).valueOrNull ?? const <String, double>{};
    final share = shares[_selectedBrandId];
    final splitShare = (share != null && share > 0 && share < 100) ? share : null;
    final directFlow = isCashEarn || splitShare != null;
    final cashEarnCoins = _isAmountValid && cashEarnPercent > 0
        ? (_totalVoucherValue * cashEarnPercent).round() / 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 120,
                  height: 70,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: BrandImage(imageUrl: brand.resolvedImageUrl, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brand.brandName ?? '', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('E-Gift Cards', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF78DEFF), Color(0xFF488599)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: const Color(0xFF78DEFF).withValues(alpha: 0.5), blurRadius: 4)],
                        ),
                        child: Text(
                          brand.category ?? 'Gift voucher',
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Amount box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Amount', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                if (_isFivePercentEarnSku) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF8F4FF), border: Border.all(color: const Color(0xFFE8DCFF)), borderRadius: BorderRadius.circular(9)),
                    child: Row(
                      children: [
                        Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Buy vouchers starting at ₹100 and earn up to ${_earnPercent.toStringAsFixed(0)}% cashback in SuperCoins!', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF6B46A5)))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_min > 0 && _min == _max) ...[
                  Wrap(
                    spacing: 6,
                    children: [
                      Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: const Color(0xFF9747FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF9747FF)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
                        alignment: Alignment.center,
                        child: Text(_formatCurrency(_min), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ],
                  ),
                  if (_discountPercent > 0) ...[
                    const SizedBox(height: 4),
                    Text('+${_formatCurrency((_min * _discountPercent / 100).roundToDouble())} cashback', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF10B981))),
                  ],
                ] else if (isFixed) ...[
                  Wrap(
                    spacing: 6,
                    children: denomList.map((denom) {
                      final isActive = _amount == denom.toInt();
                      return GestureDetector(
                        onTap: () => setState(() => _amount = denom.toInt()),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF9747FF) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isActive ? const Color(0xFF9747FF) : const Color(0xFFDAD5FF), width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(_formatCurrency(denom), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF3E3E3E))),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  Text('Enter amount between ${_formatCurrency(_min)} - ${_formatCurrency(_max)}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF555555))),
                  const SizedBox(height: 6),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: _amount == 0 ? '' : _amount.toString()),
                    onChanged: (v) {
                      final raw = v.replaceAll(RegExp(r'[^0-9]'), '');
                      setState(() => _amount = raw.isEmpty ? 0 : int.tryParse(raw) ?? 0);
                    },
                    decoration: InputDecoration(
                      hintText: '${_min.toInt()} - ${_max.toInt()}',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF9CA3AF)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD5FF), width: 2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _amount != 0 && !_isAmountValid ? Colors.red.shade400 : const Color(0xFFDAD5FF), width: 2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _amount != 0 && !_isAmountValid ? Colors.red.shade400 : const Color(0xFF9747FF), width: 2)),
                    ),
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF3E3E3E)),
                  ),
                  if (_amount != 0 && !_isAmountValid)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('Enter an amount from ${_formatCurrency(_min)} to ${_formatCurrency(_max)}.', style: GoogleFonts.poppins(fontSize: 10, color: Colors.red.shade500))),
                  if (_isAmountValid && _discountPercent > 0)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Align(alignment: Alignment.centerRight, child: Text('+${_formatCurrency((_amount * _discountPercent / 100).roundToDouble())} cashback', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w500, color: const Color(0xFF10B981))))),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Min ${_formatCurrency(_min)}', style: GoogleFonts.poppins(fontSize: 8, color: Colors.black)),
                      Text('Max ${_formatCurrency(_max)}', style: GoogleFonts.poppins(fontSize: 8, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Earn upto % SuperCoins', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
                      const SizedBox(width: 4),
                      Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                      const SizedBox(width: 4),
                      Text('upto 100 SuperCoins', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
                    ],
                  ),
                ],
                // Quantity
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _qtyButton('-', () => setState(() => _quantity = (_quantity - 1).clamp(1, 3))),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 221,
                            height: 30,
                            child: TextField(
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(text: _quantity.toString()),
                              onChanged: (v) {
                                final n = int.tryParse(v) ?? 1;
                                setState(() => _quantity = n.clamp(1, 3));
                              },
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: Color(0xFF9747FF))),
                              ),
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4E4E4E)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _qtyButton('+', _quantity >= 3 ? null : () => setState(() => _quantity = (_quantity + 1).clamp(1, 3))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black),
                            children: [
                              TextSpan(text: 'Total: ${_formatCurrency(_amount.toDouble())} x $_quantity = '),
                              TextSpan(text: _formatCurrency(_totalVoucherValue), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF9747FF))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Flipkart promo image link
          GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/scScrollableNew.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          ),

          // Expiry-extension card (Flipkart entry) — before applying a hold.
          if (!_superCoinAuthorized && _superCoinIdentity != null && !directFlow)
            SuperCoinExpiryCard(
              coinsNeeded: _superCoinsRequired,
              voucherValue: _totalVoucherValue,
              loggedIn: _superCoinIdentity != null,
              balanceLoading: scState.isSearching || scState.isBalanceLoading,
              canConvert: hasEnough,
              busy: _isCreatingOrder || _isBurning,
              paused: SuperCoinConversionConfig.paused,
              pausedMessage: SuperCoinConversionConfig.pausedMessage,
              onConvert: _openSuperCoinFlow,
              onLogin: () => context.push('/login'),
            ),

          // CASH_EARN / split-pay brands: buy through the cart instead of
          // converting coins here (React `directFlow`).
          if (directFlow)
            _buildDirectFlowCard(
              isCashEarn: isCashEarn,
              cashEarnPercent: cashEarnPercent,
              cashEarnCoins: cashEarnCoins,
              splitShare: splitShare,
            ),

          // SuperCoin CTA (React: balance for identity, login when none, active-hold when authorized)
          const SizedBox(height: 12),
          if (!_superCoinAuthorized && _superCoinIdentity != null && !directFlow) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your balance', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF667085))),
                        Row(
                          children: [
                            Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 16, height: 16),
                            const SizedBox(width: 4),
                            Text('${scState.balance.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: hasEnough ? const Color(0xFF059669) : Colors.red.shade500)),
                          ],
                        ),
                      ],
                    ),
                    if (!_isAmountValid) ...[
                      const SizedBox(height: 8),
                      Text('Enter a valid voucher amount to continue.', style: GoogleFonts.poppins(fontSize: 10, color: Colors.red.shade500)),
                    ] else if (!hasEnough) ...[
                      const SizedBox(height: 8),
                      Text("You don't have enough SuperCoins for this voucher.", style: GoogleFonts.poppins(fontSize: 10, color: Colors.red.shade500)),
                    ],
                    if (_superCoinsEarnPotential > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                          const SizedBox(width: 4),
                          Text('Earn up to ${_superCoinsEarnPotential.toStringAsFixed(2)} SC', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF667085))),
                        ],
                      ),
                    ],
                    if (_showEarnThreshold) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF8F4FF), border: Border.all(color: const Color(0xFFE8DCFF)), borderRadius: BorderRadius.circular(9)),
                        child: Row(
                          children: [
                            Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text("This denomination is below ₹100, so it won't earn SuperCoins. Choose ₹100 or more to qualify.", style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF6B46A5)))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: (hasEnough && !_isCreatingOrder && !_isBurning) ? _openSuperCoinFlow : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9747FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isCreatingOrder || _isBurning) ...[
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              const SizedBox(width: 8),
                            ] else ...[
                              Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 16, height: 16),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _isCreatingOrder ? 'Creating order...' : _isBurning ? 'Converting...' : 'Convert your Supercoins',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_superCoinIdentity == null && !directFlow) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    Text('Login to convert your SuperCoins into vouchers.', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF667085))),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/login'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9747FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 16, height: 16),
                            const SizedBox(width: 6),
                            Text('Login/Register to Convert', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_superCoinAuthorized && _superCoinHoldContext != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF9747FF).withValues(alpha: 0.08), border: Border.all(color: const Color(0xFF9747FF).withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('SuperCoins applied', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF7C3AED))),
                            const SizedBox(width: 6),
                            Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 20, height: 20),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _superCoinAuthorized = false;
                              _superCoinHoldContext = null;
                            });
                          },
                          child: Text('Remove', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF7C3AED), decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                    if (_transactionTime != null && !_countdownExpired) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 12, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 4),
                          Text('Use within ${_formatCountdown(_countdownSeconds)}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF7C3AED))),
                        ],
                      ),
                    ],
                    if (_countdownExpired) ...[
                      const SizedBox(height: 4),
                      Text('Hold expired. Please apply again.', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.red.shade500)),
                    ],
                    if (_superCoinsEarnPotential > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                          const SizedBox(width: 4),
                          Text('Earn up to ${_superCoinsEarnPotential.toStringAsFixed(2)} SC', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF7C3AED))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: (_isBurning || _countdownExpired) ? null : () => _handleBurnComplete(_superCoinHoldContext!),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9747FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isBurning) ...[
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              const SizedBox(width: 8),
                            ] else ...[
                              const Icon(Icons.check, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                            ],
                            Text(_isBurning ? 'Processing...' : 'Confirm', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
            ],

          // Info tabs
          const SizedBox(height: 12),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 6))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoTab('i', 'About', 0),
                _infoTab('*', 'How to Use', 1),
                _infoTab('#', 'Terms', 2),
              ],
            ),
          ),
          if (_activeTab != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(4, 4))]),
              child: Text(
                _activeTab == 0
                    ? (brand.description ?? 'No description available.')
                    : _activeTab == 1
                        ? ((brand.howToUse ?? '').isNotEmpty ? brand.howToUse! : 'No instructions available.')
                        : (brand.terms ?? 'No terms available.'),
                style: GoogleFonts.poppins(fontSize: 12, height: 1.5, color: const Color(0xFF4B5563)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// CASH_EARN / split-pay brands: add to cart and open it in SuperCoins
  /// reward mode so the order is placed with cashback off (React
  /// `handleCashEarnBuy`).
  Future<void> _handleDirectBuy() async {
    final brand = _brand;
    if (brand == null || !_isAmountValid) return;
    ref.read(cartProvider.notifier).addToCart(AddToCartRequest(
          brandId: brand.brandId ?? '',
          brandName: brand.brandName ?? '',
          quantity: _quantity,
          unitValue: _amount.toDouble(),
          image: brand.resolvedImageUrl,
        ));
    ref.read(cartCheckoutProvider.notifier).setRewardMode(RewardMode.superCoins);
    widget.onClose();
    if (mounted) context.go('/cart');
  }

  Widget _buildDirectFlowCard({
    required bool isCashEarn,
    required double cashEarnPercent,
    required double cashEarnCoins,
    required double? splitShare,
  }) {
    final message = isCashEarn
        ? 'Pay with UPI or card and earn ${cashEarnPercent > 0 ? '${cashEarnPercent.toStringAsFixed(cashEarnPercent % 1 == 0 ? 0 : 1)}% ' : ''}back in SuperCoins. You earn SuperCoins instead of wallet cashback on this order.'
        : 'Pay up to ${splitShare?.toStringAsFixed(splitShare % 1 == 0 ? 0 : 1)}% of this voucher with SuperCoins and the rest with UPI or card. You choose the split in your cart.';
    final buttonLabel = isCashEarn
        ? (cashEarnCoins > 0
            ? 'Buy and earn ${cashEarnCoins.toStringAsFixed(2)} SuperCoins'
            : 'Buy and earn SuperCoins')
        : 'Buy with SuperCoins + cash';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F4FF),
              border: Border.all(color: const Color(0xFFE8DCFF)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF6B46A5), height: 1.3)),
                ),
              ],
            ),
          ),
          if (isCashEarn && cashEarnCoins > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                const SizedBox(width: 4),
                Text('You earn about ${cashEarnCoins.toStringAsFixed(2)} SuperCoins',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF667085))),
              ],
            ),
          ],
          if (!_isAmountValid) ...[
            const SizedBox(height: 8),
            Text('Enter a valid voucher amount to continue.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade500)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: _isAmountValid ? _handleDirectBuy : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 16, height: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(buttonLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF9747FF)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: onTap == null ? Colors.grey : const Color(0xFF1A1A1A))),
      ),
    );
  }

  Widget _infoTab(String icon, String label, int idx) {
    final isActive = _activeTab == idx;
    final width = idx == 0 ? 71.0 : idx == 1 ? 102.0 : 73.0;
    return SizedBox(
      width: width,
      height: 30,
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = isActive ? null : idx),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFEDEAFF), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF9747FF))),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF9747FF))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessUI(SuperCoinState scState, double balance) {
    final redeemed = _burnResultData?['coinsRedeemed'];
    final earned = _burnResultData?['coinsEarned'] ?? _orderDetailsCoinsEarned;
    final freshBalance = _burnResultData?['balance'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text('Voucher Purchased!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Your SuperCoin E-Gift Voucher has been created successfully.', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF9747FF).withValues(alpha: 0.08), border: Border.all(color: const Color(0xFF9747FF).withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                if (_orderDetailsLoading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9747FF))),
                      const SizedBox(width: 8),
                      Text('Fetching earned coins...', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B46A5))),
                    ],
                  ),
                ] else ...[
                  if (earned != null) ...[
                    Text('SuperCoin Reward', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B46A5))),
                    const SizedBox(height: 4),
                    Text('You earned ${earned.toString()} SuperCoins for this order.', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B46A5))),
                    const SizedBox(height: 8),
                  ],
                  if (freshBalance != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Balance: ', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                        const SizedBox(width: 4),
                        Text('${freshBalance.toStringAsFixed(0)} coins', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  if (redeemed != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Redeemed: ', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                        const SizedBox(width: 4),
                        Text('${redeemed is num ? redeemed.toStringAsFixed(0) : redeemed} coins', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => launchUrl(
                Uri.parse('https://flipkartsupercoin.woohoo.in/claimReward'),
                mode: LaunchMode.externalApplication,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 16, height: 16),
                  const SizedBox(width: 6),
                  Text('Redeem your voucher', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                if (mounted) context.go('/orders');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9747FF),
                side: const BorderSide(color: Color(0xFF9747FF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('View in Orders', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onClose,
            child: Text('Close', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF667085))),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(double balance) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(_burnErrorTitle, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(_burnErrorDescription, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Balance: ', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                const SizedBox(width: 4),
                Text('${(balance > 0 ? balance : _burnErrorBalance ?? 0).toStringAsFixed(0)} coins', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _burnError = false;
                    _burnErrorTitle = '';
                    _burnErrorDescription = '';
                  }),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF9747FF)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text('Try Again', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF9747FF))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6), foregroundColor: const Color(0xFF667085), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  child: Text('Close', style: GoogleFonts.poppins(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? normalizeMobileToE164(String? mobile) {
  if (mobile == null || mobile.trim().isEmpty) return null;
  final trimmed = mobile.trim();
  final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('+') && digitsOnly.length >= 10) return '+$digitsOnly';
  if (digitsOnly.length == 10) return '+91$digitsOnly';
  if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) return '+$digitsOnly';
  return trimmed.startsWith('+') ? trimmed : '+${digitsOnly.isNotEmpty ? digitsOnly : trimmed}';
}
