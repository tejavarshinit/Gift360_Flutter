import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gift360/features/reseller/data/reseller_api.dart';
import 'package:gift360/features/reseller/data/reseller_store.dart';
import 'package:gift360/features/reseller/presentation/providers/reseller_provider.dart';

/// Reseller cart + checkout. Orders are created directly from the local cart
/// (wallet debited atomically server-side). Ported from React
/// `pages/ResellerCart.tsx`.
class ResellerCartScreen extends ConsumerStatefulWidget {
  const ResellerCartScreen({super.key});

  @override
  ConsumerState<ResellerCartScreen> createState() => _ResellerCartScreenState();
}

class _ResellerCartScreenState extends ConsumerState<ResellerCartScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  double? _wallet;
  bool _placing = false;
  String? _orderError;
  Map<String, dynamic>? _placed;
  bool _walletTriggered = false;

  @override
  void initState() {
    super.initState();
    _loadBuyer();
  }

  Future<void> _loadBuyer() async {
    final buyer = await ResellerStore.getBuyer();
    if (buyer == null || !mounted) return;
    setState(() {
      _name.text = buyer.fullName;
      _email.text = buyer.email;
      _mobile.text = buyer.mobile;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _refreshWallet() async {
    try {
      final wallet = await ref.read(resellerApiProvider).fetchWallet();
      if (mounted) setState(() => _wallet = wallet);
    } catch (_) {
      if (mounted) setState(() => _wallet = null);
    }
  }

  bool get _buyerValid =>
      _name.text.trim().isNotEmpty &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim()) &&
      RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim());

  String _money(double v) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(v);

  Future<void> _placeOrder(List<ResellerCartItem> items) async {
    setState(() => _orderError = null);
    if (items.isEmpty) return;
    if (!_buyerValid) {
      setState(
        () => _orderError =
            'Enter buyer details: full name, valid email and 10-digit mobile.',
      );
      return;
    }
    final parts = _name.text.trim().split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1
        ? parts.sublist(1).join(' ')
        : parts.first;

    setState(() => _placing = true);
    try {
      final buyer = ResellerBuyer(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        mobile: _mobile.text.trim(),
      );
      final signature = jsonEncode({
        'items': items.map((i) => i.toJson()).toList(),
        'buyer': buyer.toJson(),
      });
      final idempotencyKey = await ResellerStore.getOrderIdempotencyKey(
        signature,
      );

      final result = await ref.read(resellerApiProvider).createOrder({
        'order': {
          'clientOrderRef':
              'FE-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
          'currency': 'INR',
          'customer': {
            'firstName': firstName,
            'lastName': lastName,
            'email': buyer.email,
            'mobile': buyer.mobile,
          },
        },
        'items': items
            .map(
              (i) => {
                'brandSku': i.brandSku,
                'brandName': i.brandName,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
              },
            )
            .toList(),
      }, idempotencyKey);

      await ResellerStore.saveBuyer(buyer);
      await ref.read(resellerCartProvider.notifier).clear();
      await ResellerStore.clearOrderIdempotencyKey();
      if (!mounted) return;
      setState(() => _placed = result);
      _refreshWallet();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order placed • ${result['orderNumber']} • ${result['status']}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      final status = ResellerApi.statusOf(e);
      if (!mounted) return;
      if (e is DioException) {
        debugPrint(
          '[Reseller checkout] ${e.type} ${e.requestOptions.uri}: ${e.message}',
        );
      }
      if (e is DioException && e.type == DioExceptionType.receiveTimeout) {
        setState(
          () => _orderError =
              'Order processing is taking longer than expected. Check Recent orders before retrying.',
        );
      } else if (status == null) {
        setState(
          () => _orderError =
              "Couldn't reach the payment service. Check your connection and try again.",
        );
      } else if (status == 402) {
        var available = _wallet?.toStringAsFixed(2) ?? '-';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            final v = data['availableBalance'] ?? data['available'];
            if (v != null) available = v.toString();
          }
        }
        setState(
          () => _orderError =
              'Insufficient wallet balance for this order. Available: $available',
        );
      } else if (status == 401) {
        setState(() => _orderError = 'Session expired. Please login again.');
      } else if (status == 502 &&
          e is DioException &&
          ResellerApi.errorMessage(e, '').startsWith('PARTIAL')) {
        // The server has already charged delivered lines and refunded failed
        // ones. Match React by clearing the cart so the order cannot be retried.
        await ref.read(resellerCartProvider.notifier).clear();
        await ResellerStore.clearOrderIdempotencyKey();
        await _refreshWallet();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Order partly delivered. Delivered vouchers were charged; failed items were refunded.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        context.go('/reseller/dashboard');
      } else {
        setState(
          () => _orderError = ResellerApi.errorMessage(
            e,
            "Couldn't place the order. Please try again.",
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(resellerSessionProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reseller cart')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/reseller/login'),
            child: const Text('Reseller login'),
          ),
        ),
      );
    }

    if (!_walletTriggered) {
      _walletTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshWallet());
    }

    final items = ref.watch(resellerCartProvider);
    final subtotal = items.fold<double>(
      0,
      (s, i) => s + i.unitPrice * i.quantity,
    );
    final total = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final discount = subtotal - total;
    final insufficient = _wallet != null && total > _wallet!;
    final cartQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final canPlaceOrder = !_placing && !insufficient && _buyerValid;

    if (_placed != null) {
      return _buildPlacedResult(_placed!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reseller/catalog');
            }
          },
        ),
        title: Text(
          'Your Cart${items.isEmpty ? '' : '  $cartQuantity items'}',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/reseller/dashboard'),
            icon: const Icon(Icons.home_outlined, color: Color(0xFF6B21A8)),
            tooltip: 'Dashboard',
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your cart is empty',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => context.push('/reseller/catalog'),
                    child: const Text('Browse catalog'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...items.map((i) => _buildItemCard(i)),
                const SizedBox(height: 8),
                _buildTotals(subtotal, discount, total, insufficient),
                const SizedBox(height: 16),
                _buildBuyerForm(),
                if (_orderError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _orderError!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 92),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL PAYABLE',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            _money(total),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: const Color(0xFF6B21A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: canPlaceOrder
                                  ? const [Color(0xFFA855F7), Color(0xFF3B82F6)]
                                  : const [
                                      Color(0x80A855F7),
                                      Color(0x803B82F6),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: canPlaceOrder
                                ? const [
                                    BoxShadow(
                                      color: Color(0x337C3AED),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: canPlaceOrder
                                  ? () => _placeOrder(items)
                                  : null,
                              borderRadius: BorderRadius.circular(24),
                              child: Center(
                                child: _placing
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Placing order...',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Place Order',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildItemCard(ResellerCartItem item) {
    final images = item.image;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F1F4)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 80,
              height: 56,
              color: const Color(0xFFF9FAFB),
              child: images != null && images.isNotEmpty
                  ? Image.network(
                      images,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.card_giftcard,
                          color: Color(0xFF9747FF),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.card_giftcard,
                        color: Color(0xFF9747FF),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.brandName,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_money(item.unitPrice)} each${item.discount > 0 ? ' • ${item.discount.toStringAsFixed(0)}% off' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _qtyButton(Icons.remove, () {
                      ref
                          .read(resellerCartProvider.notifier)
                          .setQuantity(item.brandSku, item.quantity - 1);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _qtyButton(
                      Icons.add,
                      () => ref
                          .read(resellerCartProvider.notifier)
                          .setQuantity(item.brandSku, item.quantity + 1),
                      disabled: item.quantity >= maxResellerQuantityPerSku,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(item.lineTotal),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => ref
                    .read(resellerCartProvider.notifier)
                    .remove(item.brandSku),
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(
    IconData icon,
    VoidCallback onTap, {
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(
          icon,
          size: 14,
          color: disabled ? const Color(0xFFBDBFC6) : const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildTotals(
    double subtotal,
    double discount,
    double total,
    bool insufficient,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F1F4)),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', _money(subtotal)),
          if (discount > 0)
            _totalRow(
              'Reseller discount',
              '-${_money(discount)}',
              color: const Color(0xFF16A34A),
            ),
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 14,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                'Wallet: ${_wallet == null ? '—' : _money(_wallet!)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          _totalRow('Total payable', _money(total), bold: true),
          if (insufficient)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Insufficient wallet balance for this order.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: bold ? 13 : 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: bold ? 15 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F1F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buyer details',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: _buyerInputDecoration('Full name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: _buyerInputDecoration('Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: _buyerInputDecoration(
              '10-digit mobile',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buyerInputDecoration(
    String placeholder, {
    String? counterText,
  }) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: const Color(0xFF9CA3AF),
      ),
      counterText: counterText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF9747FF)),
      ),
    );
  }

  Widget _buildPlacedResult(Map<String, dynamic> placed) {
    final items = (placed['items'] as List?) ?? const [];
    final hasProcessing = items.any(
      (i) =>
          i is Map &&
          (i['fulfillmentStatus'] ?? '').toString().toUpperCase() ==
              'PROCESSING',
    );
    final hasCredentials = items.any(
      (i) => i is Map && ((i['credentials'] as List?) ?? const []).isNotEmpty,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => context.go('/reseller/dashboard'),
        ),
        title: Text(
          'Order placed',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 52,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(height: 10),
                Text(
                  (placed['orderNumber'] ?? '').toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    (placed['status'] ?? '').toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7E22CE),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount charged',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      _money(
                        ((placed['totalAmount'] as num?)?.toDouble()) ?? 0,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasCredentials) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your vouchers',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...items.whereType<Map>().expand((item) {
                    final credentials =
                        (item['credentials'] as List?) ?? const [];
                    return credentials.whereType<Map>().map((c) {
                      final card = (c['cardNumber'] ?? '').toString();
                      final pin = (c['cardPin'] ?? '').toString();
                      final code = (c['activationCode'] ?? '').toString();
                      final expiry = (c['expiry'] ?? '').toString();
                      final url = (c['activationUrl'] ?? '').toString();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF3E8FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['brandName'] ?? '').toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6B21A8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (card.isNotEmpty) _resultRow('Card no.', card),
                            if (pin.isNotEmpty) _resultRow('PIN', pin),
                            if (code.isNotEmpty) _resultRow('Code', code),
                            if (expiry.isNotEmpty) _resultRow('Expiry', expiry),
                            if (url.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: InkWell(
                                  onTap: () async {
                                    final uri = Uri.tryParse(url);
                                    if (uri != null) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Open activation link',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF7E22CE),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    });
                  }),
                  if (hasProcessing)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Some items are still processing - check Recent orders on the dashboard shortly.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.go('/reseller/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF523DA9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'Back to Dashboard',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push('/reseller/catalog'),
            child: const Text('Continue shopping'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
