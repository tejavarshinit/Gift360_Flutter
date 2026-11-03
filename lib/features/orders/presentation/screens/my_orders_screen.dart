import 'package:flutter/material.dart';
import 'package:gift360/core/widgets/react_backdrop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:gift360/core/widgets/app_bottom_nav.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';
import 'package:gift360/features/orders/presentation/providers/orders_provider.dart';

/// A voucher is "issued" when at least one order item carries a coupon group
/// (gift_voucher_item_coupon_details from /v1/neworders) or the item's
/// provider status reached COMPLETE — same rule as the vouchers page.
bool _hasIssuedVoucher(Map<String, dynamic> order) {
  final items = order['items'];
  if (items is! List) return false;
  for (final raw in items) {
    if (raw is! Map) continue;
    final it = Map<String, dynamic>.from(raw);
    final coupons = it['gift_voucher_item_coupon_details'];
    if (coupons is List && coupons.isNotEmpty) return true;
    final providerStatus =
        (it['provider_status'] ?? it['providerStatus'] ?? '').toString().toUpperCase();
    if (providerStatus == 'COMPLETE') return true;
  }
  return false;
}

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  int _tab = 0; // 0 = Success, 1 = Failed, 2 = Pending

  void _handleViewNow(String orderNumber) {
    context.push('/my-orders/$orderNumber/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!isAuthenticated || user == null) {
      return _buildLoginPrompt(context);
    }

    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: const ReactBackdropBackground(),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, ordersAsync),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(ordersProvider),
                    child: ordersAsync.when(
                      loading: () => _buildLoadingList(),
                      error: (e, _) => _buildErrorState(),
                      data: (data) => _buildTabContent(data),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: -1),
    );
  }

  // ─────────────────────────────────────────────
  // Header: Back to Home + refresh + title + tabs
  // ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AsyncValue<OrdersData> ordersAsync) {
    final loading = ordersAsync.isLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => context.go('/'),
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
                        'Back to Home',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: loading ? null : () => ref.invalidate(ordersProvider),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7B5CFF),
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          size: 16,
                          color: Color(0xFF7B5CFF),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'YOUR PURCHASES',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: const Color(0xFF888888),
            ),
          ),
          Text(
            'My Orders',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          _buildTabs(ordersAsync),
        ],
      ),
    );
  }

  Widget _buildTabs(AsyncValue<OrdersData> ordersAsync) {
    final data = ordersAsync.valueOrNull;
    final merged = _mergeOrders(data);
    final successCount =
        merged.where((o) => orderStatus(o) == 'PAID' && _hasIssuedVoucher(o)).length;
    final failedCount =
        merged.where((o) => orderStatus(o) == 'PAID' && !_hasIssuedVoucher(o)).length;
    final pendingCount = merged.where((o) => orderStatus(o) == 'PENDING').length;

    final tabs = [
      (label: 'Success', icon: Icons.local_offer_outlined, count: successCount),
      (label: 'Failed', icon: Icons.schedule, count: failedCount),
      (label: 'Pending', icon: Icons.credit_card, count: pendingCount),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _buildTabButton(i, tabs[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(
    int index, ({
    String label,
    IconData icon,
    int count,
  }) tab) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFF5B3FFF)],
                )
              : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 14,
              color: isActive ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tab.label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
            if (tab.count > 0) ...[
              const SizedBox(width: 4),
              Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFF7B5CFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${tab.count}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color(0xFF7B5CFF),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Content
  // ─────────────────────────────────────────────
  List<Map<String, dynamic>> _mergeOrders(OrdersData? data) {
    if (data == null) return [];
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    void addOrders(List<Map<String, dynamic>> orders) {
      for (final o in orders) {
        final key = o['order_number']?.toString() ?? o['order_id']?.toString() ?? '';
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        merged.add(o);
      }
    }

    addOrders(data.cashOrders);
    addOrders(data.superCoinOrders);

    merged.sort((a, b) {
      final da = DateTime.tryParse(orderCreatedAt(a) ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(orderCreatedAt(b) ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });
    return merged;
  }

  Widget _buildTabContent(OrdersData data) {
    final merged = _mergeOrders(data);
    final successOrders = merged
        .where((o) => orderStatus(o) == 'PAID' && _hasIssuedVoucher(o))
        .toList();
    final failedOrders = merged
        .where((o) => orderStatus(o) == 'PAID' && !_hasIssuedVoucher(o))
        .toList();
    final pendingOrders =
        merged.where((o) => orderStatus(o) == 'PENDING').toList();

    final visibleOrders = switch (_tab) {
      0 => successOrders,
      1 => failedOrders,
      _ => pendingOrders,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (_tab == 2 && pendingOrders.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF92400E),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text:
                        'These orders are awaiting payment. Tap ',
                  ),
                  TextSpan(
                    text: 'Pay Now',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        ' to review this order and complete payment.',
                  ),
                ],
              ),
            ),
          ),
        ],
        if (visibleOrders.isEmpty)
          _buildEmptyState()
        else
          ...visibleOrders.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OrderRow(
                  order: order,
                  onViewNow: _handleViewNow,
                ),
              )),
      ],
    );
  }

  Widget _buildEmptyState() {
    final (icon, title, subtitle) = switch (_tab) {
      0 => (
          Icons.local_offer_outlined,
          'No Vouchers Yet',
          'Your purchased vouchers will appear here after payment',
        ),
      1 => (
          Icons.schedule,
          'No Orders Pending Voucher',
          "Paid orders whose vouchers haven't been issued yet will appear here",
        ),
      _ => (
          Icons.credit_card,
          'No Pending Payments',
          "Orders where payment wasn't completed will appear here",
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7B5CFF).withValues(alpha: 0.1),
                  const Color(0xFF8A5AA0).withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Icon(icon, size: 40, color: const Color(0xFF7B5CFF)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 3,
      itemBuilder: (_, index) => Container(
        height: 88,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Failed to load',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Could not fetch your orders',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(ordersProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B5CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text('Retry', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: const ReactBackdropBackground(),
          ),
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
                    'Login to view your orders',
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

// ─────────────────────────────────────────────
// Order Row
// ─────────────────────────────────────────────
class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final void Function(String orderNumber) onViewNow;

  const _OrderRow({required this.order, required this.onViewNow});

  @override
  Widget build(BuildContext context) {
    final items = order['items'] is List
        ? List<Map<String, dynamic>>.from(
            (order['items'] as List).whereType<Map>(),
          )
        : <Map<String, dynamic>>[];
    final meta = items.isNotEmpty
        ? (items.first['meta'] is Map
            ? Map<String, dynamic>.from(items.first['meta'] as Map)
            : <String, dynamic>{})
        : <String, dynamic>{};

    final brandName = meta['brand_name']?.toString() ??
        'Order #${(order['order_number']?.toString() ?? '').substring((order['order_number']?.toString() ?? '').length > 8 ? (order['order_number']!.toString().length - 8) : 0)}';
    final imageUrl = orderItemImageUrl(meta);
    final amount = orderTotalAmount(order);
    final coinsRedeemed =
        (order['pricing'] is Map ? (order['pricing'] as Map)['coins_redeemed'] : null);
    final coins = coinsRedeemed is num ? coinsRedeemed.toDouble() : 0.0;
    final isSuperCoin = coins > 0 ||
        (order['payment_method'] ?? order['type'] ?? '').toString().toUpperCase() ==
            'SUPERCOIN';
    final extraItems = items.length - 1;
    final status = orderStatus(order);
    final orderNumber = order['order_number']?.toString() ?? '';

    final dateStr = _formatDate(orderCreatedAt(order));

    final (badgeLabel, badgeBg, badgeColor, badgeBorder) = status == 'PENDING'
        ? (
            'Pending',
            const Color(0xFFFFF7ED),
            const Color(0xFFC2410C),
            const Color(0xFFFDBA74),
          )
        : _hasIssuedVoucher(order)
            ? (
                'Vouchers Issued',
                const Color(0xFFECFDF5),
                const Color(0xFF047857),
                const Color(0xFF6EE7B7),
              )
            : (
                'Voucher Pending',
                const Color(0xFFFEFCE8),
                const Color(0xFFA16207),
                const Color(0xFFFDE047),
              );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: BrandImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              brandName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (extraItems > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF7B5CFF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '+$extraItems more',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7B5CFF),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isSuperCoin && coins > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${coins.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Image.asset(
                            'assets/images/SuperCOin-removebg-preview.png',
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                        ],
                      )
                    else
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                  ],
                ),
                if (orderNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Order #$orderNumber',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFF888888),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        badgeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          dateStr,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: const Color(0xFF5E5E5E),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (status == 'PENDING' && orderNumber.isNotEmpty)
                      GestureDetector(
                        onTap: () => onViewNow(orderNumber),
                        child: Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFD79A8),
                                Color(0xFFB96BC6),
                                Color(0xFF6C5CE7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pay Now',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
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

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy, hh:mma').format(dt);
  }
}
