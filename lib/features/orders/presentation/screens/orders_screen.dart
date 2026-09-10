import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';
import 'package:gift360/features/orders/presentation/providers/orders_provider.dart';
import 'package:gift360/features/orders/presentation/widgets/orders_empty_state.dart';
import 'package:gift360/features/orders/presentation/widgets/pending_card.dart';
import 'package:gift360/features/orders/presentation/widgets/redeemed_card.dart';
import 'package:gift360/features/orders/presentation/widgets/voucher_card.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/core/widgets/app_bottom_nav.dart';

enum _OrdersTab { vouchers, pending, redeemed }

enum _VoucherSubTab { cash, supercoin }

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  _OrdersTab _tab = _OrdersTab.vouchers;
  _VoucherSubTab _voucherSubTab = _VoucherSubTab.cash;
  String? _expandedId;
  RedeemedEntry? _successEntry;
  bool _autoExpand = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand the latest order when returning from a successful payment
    // (matches React's justReturnedFromPayment sessionStorage flow).
    PaymentNotifier.consumeJustReturnedFromPayment().then((value) {
      if (value && mounted) setState(() => _autoExpand = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!isAuthenticated || user == null) {
      return _buildLoginPrompt(context);
    }

    final ordersAsync = ref.watch(ordersProvider);
    final redeemed = ref.watch(redeemedVouchersProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Aurora background
          Positioned.fill(
            child: Image.asset(
              'assets/images/ganeshbackdrop.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, ordersAsync, redeemed.length),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(ordersProvider),
                    child: ordersAsync.when(
                      loading: () => _buildLoadingList(),
                      error: (e, _) => _buildErrorState(),
                      data: (data) => _buildTabContent(context, data, redeemed),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_successEntry != null)
            _buildSuccessOverlay(context, _successEntry!),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: -1),
    );
  }

  // ─────────────────────────────────────────────
  // Aurora Background (matches Cart)
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
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header (Section 4A)
  // ─────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    AsyncValue<OrdersData> ordersAsync,
    int redeemedCount,
  ) {
    final data = ordersAsync.valueOrNull;
    final allOrders = data?.allOrders ?? const <Map<String, dynamic>>[];
    final paidCount = allOrders.where((o) => _isPaidAndUnredeemed(o)).length;
    final pendingCount = allOrders.where((o) => _isPending(o)).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to Home button
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    size: 16,
                    color: Color(0xFF1A1A1A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Back to Home',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR WALLET',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF888888),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'My Vouchers',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => ref.invalidate(ordersProvider),
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
                  child: ordersAsync.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7B5CFF),
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: Color(0xFF7B5CFF),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                _tabPill(
                  _OrdersTab.vouchers,
                  Icons.sell_outlined,
                  'Vouchers',
                  paidCount,
                ),
                _tabPill(
                  _OrdersTab.pending,
                  Icons.schedule,
                  'Pending',
                  pendingCount,
                ),
                _tabPill(
                  _OrdersTab.redeemed,
                  Icons.check_circle_outline,
                  'Redeemed',
                  redeemedCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabPill(_OrdersTab tab, IconData icon, String label, int count) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF7B61FF), Color(0xFF5B3FFF)],
                  )
                : null,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  count > 0 ? '$count $label' : label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Filtering helpers
  bool _isPending(Map<String, dynamic> order) => [
    'PENDING',
    'FAILED',
    'CANCELLED',
    'TAMPERED',
  ].contains(orderStatus(order));

  bool _isPaidAndUnredeemed(Map<String, dynamic> order) {
    if (orderStatus(order) != 'PAID') return false;
    final id = orderId(order);
    final orderNumber = order['order_number']?.toString() ?? '';
    final redeemed = ref.read(redeemedVouchersProvider);
    return !redeemed.any((r) => r.id == id || r.orderNumber == orderNumber);
  }

  Widget _subTabPill(_VoucherSubTab tab, String label, int count) {
    final selected = _voucherSubTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _voucherSubTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF7B5CFF).withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF7B5CFF) : Colors.grey.shade200,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tab == _VoucherSubTab.cash)
                  Icon(
                    Icons.credit_card_outlined,
                    size: 14,
                    color: selected
                        ? const Color(0xFF7B5CFF)
                        : Colors.grey.shade600,
                  )
                else
                  Image.asset(
                    'assets/images/SuperCOin-removebg-preview.png',
                    width: 16,
                    height: 16,
                  ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    count > 0 ? '$label ($count)' : label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? const Color(0xFF7B5CFF)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tab content
  Widget _buildTabContent(
    BuildContext context,
    OrdersData data,
    List<RedeemedEntry> redeemed,
  ) {
    switch (_tab) {
      case _OrdersTab.vouchers:
        // Get paid orders from the appropriate sub-tab source
        List<Map<String, dynamic>> paidOrders;
        switch (_voucherSubTab) {
          case _VoucherSubTab.cash:
            paidOrders = data.cashOrders.where(_isPaidAndUnredeemed).toList();
            break;
          case _VoucherSubTab.supercoin:
            paidOrders = data.superCoinOrders
                .where(_isPaidAndUnredeemed)
                .toList();
            break;
        }

        // Filter orders based on sub-tab
        final cashCount = data.cashOrders.where(_isPaidAndUnredeemed).length;
        final supercoinCount = data.superCoinOrders
            .where(_isPaidAndUnredeemed)
            .length;

        // Auto-expand the latest order once after returning from payment.
        if (_autoExpand && _expandedId == null && paidOrders.isNotEmpty) {
          _expandedId = orderId(paidOrders.first);
          _autoExpand = false;
        }

        return Column(
          children: [
            // Sub-tab bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _subTabPill(_VoucherSubTab.cash, 'Cash Orders', cashCount),
                  const SizedBox(width: 8),
                  _subTabPill(
                    _VoucherSubTab.supercoin,
                    'SuperCoins Orders',
                    supercoinCount,
                  ),
                ],
              ),
            ),
            Expanded(
              child: paidOrders.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        OrdersEmptyState(
                          icon: Icons.sell_outlined,
                          title:
                              'No ${_voucherSubTab == _VoucherSubTab.cash ? 'Cash' : 'SuperCoin'} Vouchers',
                          subtitle: 'Vouchers will appear here after payment',
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // 2-column grid, matching React's flex-wrap with gap-2
                        // and each card w-[172px].
                        final cardWidth = (constraints.maxWidth - 40) / 2;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: paidOrders.map((order) {
                              final id = orderId(order);
                              return SizedBox(
                                width: cardWidth,
                                child: VoucherCard(
                                  key: ValueKey(id),
                                  order: order,
                                  clientId:
                                      ref.read(authProvider)?.clientId ?? '',
                                  isSuperCoin:
                                      _voucherSubTab ==
                                      _VoucherSubTab.supercoin,
                                  expanded: _expandedId == id,
                                  onToggle: () => setState(
                                    () => _expandedId = _expandedId == id
                                        ? null
                                        : id,
                                  ),
                                  onRedeemed: (vouchers) =>
                                      _handleRedeemed(order, vouchers),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );

      case _OrdersTab.pending:
        final pendingOrders = data.allOrders.where(_isPending).toList();
        if (pendingOrders.isEmpty) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: const [
              OrdersEmptyState(
                icon: Icons.schedule,
                title: 'No Pending Orders',
                subtitle: 'All your orders have been processed',
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
          itemCount: pendingOrders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => PendingCard(
            key: ValueKey(orderId(pendingOrders[index])),
            order: pendingOrders[index],
          ),
        );

      case _OrdersTab.redeemed:
        if (redeemed.isEmpty) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: const [
              OrdersEmptyState(
                icon: Icons.check_circle_outline,
                title: 'No Redeemed Vouchers',
                subtitle:
                    "Vouchers you've used at merchants will appear here after balance confirmation",
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
          itemCount: redeemed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => RedeemedCard(
            key: ValueKey(redeemed[index].id),
            item: redeemed[index],
          ),
        );
    }
  }

  Widget _buildLoadingList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
      children: List.generate(
        3,
        (i) => Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE5E0F0).withValues(alpha: 0.5),
                const Color(0xFFD5CEE8).withValues(alpha: 0.5),
              ],
            ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(0xFFF87171),
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Could not fetch your orders',
              style: GoogleFonts.poppins(
                fontSize: 14,
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
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Redeem confirmation
  Future<void> _handleRedeemed(
    Map<String, dynamic> order,
    List<VoucherView> vouchers,
  ) async {
    final meta = firstItemMeta(order);
    final entry = RedeemedEntry(
      id: orderId(order),
      orderNumber: order['order_number']?.toString() ?? '',
      brandName: meta['brand_name']?.toString() ?? 'Voucher',
      amount: orderTotalAmount(order),
      image: orderItemImageUrl(meta),
      vouchers: vouchers,
      redeemedAt: DateTime.now().toIso8601String(),
    );
    await ref.read(redeemedVouchersProvider.notifier).add(entry);
    if (!mounted) return;
    setState(() => _successEntry = entry);
  }

  // ─────────────────────────────────────────────
  // Success Overlay (Section 11)
  // ─────────────────────────────────────────────
  Widget _buildSuccessOverlay(BuildContext context, RedeemedEntry entry) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Stack(
          children: [
            // Confetti particles
            ...List.generate(
              14,
              (i) => Positioned(
                left:
                    (12 + (i * 6) % 72) /
                    100 *
                    MediaQuery.of(context).size.width,
                top:
                    (18 + (i * 11) % 56) /
                    100 *
                    MediaQuery.of(context).size.height,
                child: Container(
                  width: 4 + (i % 3).toDouble(),
                  height: 4 + (i % 3).toDouble(),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: [
                      const Color(0xFFFF8AA0),
                      const Color(0xFF7B5CFF),
                      const Color(0xFFF59E0B),
                      const Color(0xFF22C55E),
                      const Color(0xFF38BDF8),
                    ][i % 5],
                  ),
                ),
              ),
            ),
            // Success card
            Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 360),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 40,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFECFEFF), Color(0xFFDCFCE7)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF7B5CFF), Color(0xFF5A4BFF)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Voucher Redeemed',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Successfully',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF888888),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Container(
                        width: double.infinity,
                        height: 280,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, const Color(0xFFF7F3FF)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: const Color(0xFFECE7FF)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(
                                      0xFF7B5CFF,
                                    ).withValues(alpha: 0.16),
                                    const Color(
                                      0xFFFF8AA0,
                                    ).withValues(alpha: 0.16),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.menu_book,
                                size: 28,
                                color: Color(0xFF7B5CFF),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              entry.brandName,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Text(
                                'Tap below to open the redeemed voucher details.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF888888),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _tab = _OrdersTab.redeemed;
                            _expandedId = null;
                            _successEntry = null;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B5CFF), Color(0xFF5A4BFF)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'View Voucher',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
          ],
        ),
      ),
    );
  }

  // Logged-out state
  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF9747FF), Colors.white],
                  stops: [0.0, 0.06],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Please Login',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login to view your vouchers',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.push('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A1A1A),
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
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
