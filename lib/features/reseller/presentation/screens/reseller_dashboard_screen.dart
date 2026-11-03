import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gift360/features/reseller/data/reseller_api.dart';
import 'package:gift360/features/reseller/data/reseller_csv.dart';
import 'package:gift360/features/reseller/data/reseller_store.dart';
import 'package:gift360/features/reseller/presentation/providers/reseller_provider.dart';

String _formatResellerMoney(num? value) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
).format(value ?? 0);

/// Reseller dashboard: wallet, order history, flattened vouchers (credentials),
/// wallet transaction ledger and profile. Ported from React
/// `pages/ResellerDashboard.tsx`.
class ResellerDashboardScreen extends ConsumerStatefulWidget {
  const ResellerDashboardScreen({super.key});

  @override
  ConsumerState<ResellerDashboardScreen> createState() =>
      _ResellerDashboardScreenState();
}

class _ResellerDashboardScreenState
    extends ConsumerState<ResellerDashboardScreen> {
  bool _loading = true;
  String? _error;
  double? _wallet;
  String? _clientId;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _vouchers = [];
  bool _vouchersLoading = false;

  bool _loadTriggered = false;
  bool _disposed = false;
  int _tab = 0; // 0 completed, 1 pending, 2 failed, 3 vouchers, 4 transactions
  final Set<String> _expandedFailedOrders = {};
  final Map<String, Object?> _failedOrderDetails = {};

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) setState(fn);
  }

  /// Voucher date-range filter (yyyy-MM-dd), matching React.
  String _dateFrom = '';
  String _dateTo = '';

  Future<void> _load() async {
    if (!mounted) return;
    _safeSetState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(resellerApiProvider);
      final results = await Future.wait([
        api.fetchWallet(),
        api.fetchOrders(),
        api.fetchWalletTransactions(),
        api.fetchJwt().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      _safeSetState(() {
        _wallet = results[0] as double;
        _orders = results[1] as List<Map<String, dynamic>>;
        _transactions = results[2] as List<Map<String, dynamic>>;
        _clientId = (results[3] as Map<String, dynamic>?)?['clientId']
            ?.toString();
      });
      _loadVouchers(_orders);
    } catch (e) {
      if (!mounted) return;
      _safeSetState(
        () => _error = ResellerApi.errorMessage(
          e,
          "Couldn't reach reseller services. Please retry.",
        ),
      );
    } finally {
      if (mounted) _safeSetState(() => _loading = false);
    }
  }

  /// Flatten credentials from completed order details into voucher rows.
  Future<void> _loadVouchers(List<Map<String, dynamic>> allOrders) async {
    if (!mounted) return;
    _safeSetState(() => _vouchersLoading = true);
    try {
      final api = ref.read(resellerApiProvider);
      final completed = allOrders
          .where(
            (o) => const {
              'COMPLETED',
              'PARTIALLY_FAILED',
            }.contains((o['status'] ?? '').toString().toUpperCase()),
          )
          .take(50)
          .toList();
      final rows = <Map<String, dynamic>>[];
      for (final order in completed) {
        if (!mounted || _disposed) return;
        try {
          final details = await api.fetchOrderDetails(
            (order['orderNumber'] ?? '').toString(),
          );
          for (final item in (details['items'] as List?) ?? const []) {
            if (item is! Map) continue;
            for (final c in (item['credentials'] as List?) ?? const []) {
              if (c is! Map) continue;
              rows.add({
                'orderNumber': order['orderNumber'],
                'clientOrderRef': order['clientOrderRef'],
                'orderDate': order['createdAt'],
                'brandSku': item['brandSku'],
                'brandName': item['brandName'],
                'cardNumber': c['cardNumber'],
                'cardPin': c['cardPin'],
                'activationCode': c['activationCode'],
                'activationUrl': c['activationUrl'],
                'expiry': c['expiry'],
              });
            }
          }
        } catch (_) {
          // Skip orders whose detail can't be loaded.
        }
      }
      rows.sort(
        (a, b) => (b['orderDate'] ?? '').toString().compareTo(
          (a['orderDate'] ?? '').toString(),
        ),
      );
      if (!mounted || _disposed) return;
      _safeSetState(() => _vouchers = rows);
    } finally {
      if (mounted) _safeSetState(() => _vouchersLoading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(resellerApiProvider).logout();
    await ref.read(resellerSessionProvider.notifier).clear();
    if (mounted) context.go('/reseller');
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted || _disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredVouchers {
    return _vouchers.where((v) {
      final raw = (v['orderDate'] ?? '').toString();
      final day = raw.length >= 10 ? raw.substring(0, 10) : raw;
      if (_dateFrom.isNotEmpty && day.compareTo(_dateFrom) < 0) return false;
      if (_dateTo.isNotEmpty && day.compareTo(_dateTo) > 0) return false;
      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _voucherGroups {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final voucher in _filteredVouchers) {
      final orderNumber = (voucher['orderNumber'] ?? '').toString();
      groups.putIfAbsent(orderNumber, () => []).add(voucher);
    }
    return groups;
  }

  Future<void> _pickVoucherDate({required bool from}) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(from ? _dateFrom : _dateTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (from) {
        _dateFrom = value;
      } else {
        _dateTo = value;
      }
    });
  }

  Future<void> _openOrder(String orderNumber) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final details = await ref
          .read(resellerApiProvider)
          .fetchOrderDetails(orderNumber);
      if (!mounted) return;
      rootNav.pop();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderDetailsSheet(details: details, onCopy: _copy),
      );
    } catch (_) {
      if (!mounted) return;
      rootNav.pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't load order. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(resellerSessionProvider);
    final cartItems = ref.watch(resellerCartProvider);
    final cartCount = cartItems.fold<int>(0, (sum, i) => sum + i.quantity);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reseller'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/reseller'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Reseller login required'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/reseller/login'),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Wait for the persisted session before the first API load.
    if (!_loadTriggered) {
      _loadTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(hasScrollBody: false, child: _buildError())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWalletCard(),
                      const SizedBox(height: 16),
                      _buildQuickActions(cartCount),
                      const SizedBox(height: 16),
                      _buildStats(cartItems.length),
                      const SizedBox(height: 20),
                      _buildTabContent(cartItems),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final resellerId =
        _clientId ??
        ref.read(resellerSessionProvider)?.resellerId ??
        'Reseller';
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/reseller'),
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF374151),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reseller Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  resellerId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openProfileSheet,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9747FF), Color(0xFF3B82F6)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _avatarInitial(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9747FF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x339747FF),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Wallet Balance',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _wallet == null ? '—' : _money(_wallet!),
            style: GoogleFonts.poppins(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'INR · available for voucher purchases',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(int cartCount) {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            icon: Icons.store_outlined,
            label: 'Browse Brands',
            onTap: () => context.push('/reseller/catalog'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickAction(
            icon: Icons.shopping_cart_outlined,
            label: 'Cart',
            badge: cartCount > 0 ? '$cartCount' : null,
            onTap: () => context.push('/reseller/cart'),
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 17, color: const Color(0xFF7E22CE)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7E22CE),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7E22CE),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  Widget _buildStats(int cartLineCount) {
    final completed = _orders
        .where(
          (o) => (o['status'] ?? '').toString().toUpperCase() == 'COMPLETED',
        )
        .length;
    final pending =
        _orders
            .where(
              (o) => const {
                'PENDING',
                'PROCESSING',
                'PLACED',
              }.contains((o['status'] ?? '').toString().toUpperCase()),
            )
            .length +
        cartLineCount;
    final failed = _orders
        .where(
          (o) => const {
            'FAILED',
            'PARTIALLY_FAILED',
          }.contains((o['status'] ?? '').toString().toUpperCase()),
        )
        .length;
    final stats = [
      (Icons.shopping_bag_outlined, 'Completed', completed),
      (Icons.schedule_outlined, 'Pending', pending),
      (Icons.cancel_outlined, 'Failed', failed),
      (Icons.trending_up, 'Vouchers', _vouchers.length),
      (Icons.receipt_long_outlined, 'Txns', _transactions.length),
    ];

    return Row(
      children: List.generate(stats.length, (index) {
        final (icon, label, value) = stats[index];
        final selected = _tab == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == stats.length - 1 ? 0 : 6),
            child: GestureDetector(
              onTap: () => setState(() => _tab = index),
              child: Container(
                height: 88,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF9747FF), Color(0xFF3B82F6)],
                        )
                      : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.2)
                            : const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 15,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF7E22CE),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _loading ? '—' : '$value',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<ResellerCartItem> cartItems) {
    switch (_tab) {
      case 1:
        return _buildPendingTab(cartItems);
      case 2:
        return _buildFailedTab();
      case 3:
        return _buildVouchersTab();
      case 4:
        return _buildTransactionsTab();
      default:
        return _buildOrdersTab();
    }
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1F2937),
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final value = status.toUpperCase();
    final (background, foreground) = switch (value) {
      'COMPLETED' ||
      'COMPLETE' => (const Color(0xFFECFDF5), const Color(0xFF059669)),
      'FAILED' ||
      'PARTIALLY_FAILED' => (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      'PLACED' ||
      'PROCESSING' ||
      'PENDING' => (const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      'CREDIT' => (const Color(0xFFECFDF5), const Color(0xFF059669)),
      'DEBIT' => (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      'REFUND' => (const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
      'DISCOUNT' => (const Color(0xFFFAF5FF), const Color(0xFF7E22CE)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF4B5563)),
    };
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value.replaceAll('_', ' '),
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  String _shortDate(Object? raw) {
    final value = (raw ?? '').toString();
    return value.length >= 10
        ? value.substring(0, 10)
        : (value.isEmpty ? '—' : value);
  }

  Widget _buildOrdersTab() {
    final completed = _orders
        .where(
          (o) => (o['status'] ?? '').toString().toUpperCase() == 'COMPLETED',
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading('Completed orders'),
        if (completed.isEmpty)
          _emptyState('No completed orders yet')
        else
          ...completed.map((o) {
            final status = (o['status'] ?? '').toString().toUpperCase();
            final total = (o['totalAmount'] as num?)?.toDouble() ?? 0;
            final orderNumber = (o['orderNumber'] ?? '').toString();
            return _card(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _openOrder(orderNumber),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (o['clientOrderRef'] ?? orderNumber).toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$orderNumber · ${_shortDate(o['createdAt'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _money(total),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          _statusChip(status),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPendingTab(List<ResellerCartItem> cartItems) {
    final pending = _orders
        .where(
          (o) => const {
            'PENDING',
            'PROCESSING',
            'PLACED',
          }.contains((o['status'] ?? '').toString().toUpperCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading('Pending'),
        if (cartItems.isEmpty && pending.isEmpty)
          _emptyState('Nothing pending')
        else ...[
          if (cartItems.isNotEmpty)
            _card(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => context.push('/reseller/cart'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        size: 18,
                        color: Color(0xFF7E22CE),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cart — not ordered yet',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              cartItems
                                  .map((i) => '${i.brandName} × ${i.quantity}')
                                  .join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7E22CE),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ...pending.map((o) {
            final number = (o['orderNumber'] ?? '').toString();
            final total = (o['totalAmount'] as num?)?.toDouble() ?? 0;
            final status = (o['status'] ?? 'PENDING').toString().toUpperCase();
            return _card(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _openOrder(number),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (o['clientOrderRef'] ?? number).toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$number · ${_shortDate(o['createdAt'])} · being processed',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _money(total),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _statusChip(status),
                        ],
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFailedTab() {
    final failed = _orders
        .where(
          (o) => const {
            'FAILED',
            'PARTIALLY_FAILED',
          }.contains((o['status'] ?? '').toString().toUpperCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading('Failed orders'),
        if (failed.isEmpty)
          _emptyState('No failed orders')
        else
          ...failed.map((o) {
            final number = (o['orderNumber'] ?? '').toString();
            final status = (o['status'] ?? 'FAILED').toString().toUpperCase();
            final total = (o['totalAmount'] as num?)?.toDouble() ?? 0;
            final expanded = _expandedFailedOrders.contains(number);
            final details = _failedOrderDetails[number];
            return _card(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  InkWell(
                    onTap: () => _toggleFailedOrder(number),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (o['clientOrderRef'] ?? number).toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '$number · ${_shortDate(o['createdAt'])}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _money(total),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              _statusChip(status),
                            ],
                          ),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 19,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(
                          top: BorderSide(color: Color(0xFFF1F1F4)),
                        ),
                      ),
                      child: _buildFailedOrderDetails(details),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _toggleFailedOrder(String orderNumber) async {
    if (_expandedFailedOrders.remove(orderNumber)) {
      setState(() {});
      return;
    }
    setState(() {
      _expandedFailedOrders.add(orderNumber);
      _failedOrderDetails[orderNumber] = 'loading';
    });
    try {
      final details = await ref
          .read(resellerApiProvider)
          .fetchOrderDetails(orderNumber);
      if (!mounted) return;
      setState(() => _failedOrderDetails[orderNumber] = details);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failedOrderDetails[orderNumber] = 'error');
    }
  }

  Widget _buildFailedOrderDetails(Object? details) {
    if (details == 'loading' || details == null) {
      return Text(
        'Loading items…',
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: const Color(0xFF6B7280),
        ),
      );
    }
    if (details == 'error') {
      return Text(
        "Couldn't load the items. Collapse and open again to retry.",
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: const Color(0xFFDC2626),
        ),
      );
    }
    final items =
        (details as Map<String, dynamic>)['items'] as List? ?? const [];
    return Column(
      children: [
        ...items.whereType<Map>().map((item) {
          final failed =
              (item['fulfillmentStatus'] ?? '').toString().toUpperCase() ==
              'FAILED';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: failed ? const Color(0xFFFEF2F2) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: failed
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF3F4F6),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['brandName'] ?? '').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${item['brandSku']} · ${item['quantity']} × ${_money((item['unitPrice'] as num?)?.toDouble() ?? 0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip((item['fulfillmentStatus'] ?? 'FAILED').toString()),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Any wallet amount charged for a failed order is refunded automatically.',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportVoucherGroup(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final orderNumber = (rows.first['orderNumber'] ?? 'order').toString();
    final tag = (rows.first['clientOrderRef'] ?? orderNumber).toString();
    final safeTag = tag.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
    final fileName = 'vouchers-$safeTag.csv';
    final path = await shareCsvFile(resellerVouchersToCsv(rows), fileName);
    if (!mounted || _disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path == null ? 'CSV copied to clipboard' : 'Export ready — $fileName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openVoucherDetails(Map<String, dynamic> voucher) async {
    final card = (voucher['cardNumber'] ?? '').toString();
    final pin = (voucher['cardPin'] ?? '').toString();
    final code = (voucher['activationCode'] ?? '').toString();
    final url = (voucher['activationUrl'] ?? '').toString();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                (voucher['brandName'] ?? 'Voucher').toString(),
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
              ),
              const SizedBox(height: 14),
              if (card.isNotEmpty) _credentialRow('Card no.', card, onCopy: () => _copy(card, 'Card number')),
              if (pin.isNotEmpty) _credentialRow('PIN', pin, onCopy: () => _copy(pin, 'PIN')),
              if (code.isNotEmpty) _credentialRow('Code', code, onCopy: () => _copy(code, 'Activation code')),
              Text('Expiry: ${(voucher['expiry'] ?? '—').toString()}', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF6B7280))),
              const SizedBox(height: 12),
              if (url.isNotEmpty)
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(url);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E22CE),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Text('Open activation link', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVouchersTab() {
    final filtered = _filteredVouchers;
    final groups = _voucherGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading('Vouchers'),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _dateFilterChip('From', _dateFrom, () => _pickVoucherDate(from: true), () {
                    setState(() => _dateFrom = '');
                  }),
                  const SizedBox(width: 8),
                  _dateFilterChip('To', _dateTo, () => _pickVoucherDate(from: false), () {
                    setState(() => _dateTo = '');
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _vouchersLoading
                      ? 'Loading vouchers…'
                      : '${filtered.length} voucher${filtered.length == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
        if (_vouchersLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          _emptyState(
            _vouchers.isEmpty
                ? 'No vouchers yet'
                : 'No vouchers in this date range',
          )
        else
          ...groups.entries.map((entry) {
            final rows = entry.value;
            final first = rows.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (first['clientOrderRef'] ?? entry.key).toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${_shortDate(first['orderDate'])} · ${rows.length} voucher${rows.length == 1 ? '' : 's'}',
                              style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _exportVoucherGroup(rows),
                        icon: const Icon(Icons.grid_on, size: 14),
                        label: const Text('Export'),
                      ),
                    ],
                  ),
                  ...rows.map((v) {
                    final card = (v['cardNumber'] ?? '').toString();
                    final sku = (v['brandSku'] ?? '').toString();
                    return _card(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => _openVoucherDetails(v),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (v['brandName'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      card.isNotEmpty ? '•••• ${card.substring(card.length > 4 ? card.length - 4 : 0)}' : sku,
                                      style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF6B7280)),
                                    ),
                                  ],
                                ),
                              ),
                              if ((v['cardPin'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text('PIN', style: GoogleFonts.poppins(fontSize: 8, color: const Color(0xFF9CA3AF))),
                                ),
                              const Icon(Icons.chevron_right, size: 17, color: Color(0xFFD1D5DB)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _credentialRow(String label, String value, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: const Icon(Icons.copy, size: 14, color: Color(0xFF523DA9)),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeading('Transactions'),
          _emptyState('No transactions yet'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading('Transactions'),
        ..._transactions.map((t) {
          final type = (t['type'] ?? '').toString().toUpperCase();
          final amount = (t['amount'] as num?)?.toDouble() ?? 0;
          final credit = type == 'CREDIT' || type == 'REFUND';
          return _card(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statusChip(type.isEmpty ? 'TRANSACTION' : type),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              (t['reference'] ?? 'Wallet transaction')
                                  .toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_transactionDate(t['createdAt'])} · balance ${_money((t['balanceAfter'] as num?)?.toDouble() ?? 0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${credit ? '+' : '−'}${_money(amount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: credit
                        ? const Color(0xFF059669)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _dateFilterChip(
    String label,
    String value,
    VoidCallback onPick,
    VoidCallback onClear,
  ) {
    final hasValue = value.isNotEmpty;
    return Expanded(
      child: GestureDetector(
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasValue
                  ? const Color(0xFF523DA9)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.event, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasValue ? value : label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    color: hasValue
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              if (hasValue)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close,
                    size: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _avatarInitial() {
    final source =
        (_clientId ?? ref.read(resellerSessionProvider)?.resellerId ?? 'R')
            .trim();
    return source.isEmpty ? 'R' : source.substring(0, 1).toUpperCase();
  }

  Future<void> _openProfileSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ResellerProfileSheet(
        onChangePassword: () {
          Navigator.of(sheetContext).pop();
          context.push('/changepassword');
        },
        onLogout: () {
          Navigator.of(sheetContext).pop();
          _logout();
        },
      ),
    );
  }

  String _money(num? value) => _formatResellerMoney(value);

  String _transactionDate(Object? raw) {
    final value = (raw ?? '').toString();
    if (value.isEmpty) return '—';
    final formatted = value.replaceFirst('T', ' ');
    return formatted.substring(0, formatted.length.clamp(0, 16).toInt());
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> details;
  final void Function(String, String) onCopy;

  const _OrderDetailsSheet({required this.details, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final items = (details['items'] as List?) ?? const [];
    final total = (details['totalAmount'] as num?)?.toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                (details['orderNumber'] ?? '').toString(),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(details['status'] ?? '').toString()} · ${_formatResellerMoney(total ?? 0)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 14),
              ...items.whereType<Map>().map((item) {
                final credentials = (item['credentials'] as List?) ?? const [];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F1F4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['brandName']} × ${item['quantity']}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unit ${_formatResellerMoney((item['unitPrice'] as num?)?.toDouble() ?? 0)} · Net ${_formatResellerMoney((item['netAmount'] as num?)?.toDouble() ?? 0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (credentials.isEmpty)
                        Text(
                          'Credentials pending (${(item['fulfillmentStatus'] ?? 'PROCESSING')})',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: const Color(0xFFB45309),
                          ),
                        )
                      else
                        ...credentials.whereType<Map>().map((c) {
                          final card = (c['cardNumber'] ?? '').toString();
                          final pin = (c['cardPin'] ?? '').toString();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    [
                                      card,
                                      pin,
                                    ].where((e) => e.isNotEmpty).join(' · '),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                if (card.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => onCopy(card, 'Card number'),
                                    child: const Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Color(0xFF523DA9),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _ResellerProfileSheet extends ConsumerStatefulWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const _ResellerProfileSheet({
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  ConsumerState<_ResellerProfileSheet> createState() =>
      _ResellerProfileSheetState();
}

class _ResellerProfileSheetState extends ConsumerState<_ResellerProfileSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(resellerApiProvider).fetchProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      final status = ResellerApi.statusOf(e);
      if (!mounted) return;
      setState(
        () => _error = status == 404
            ? "Profile service isn't live yet - showing session details."
            : ResellerApi.errorMessage(
                e,
                "Couldn't load profile details. Please retry.",
              ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(resellerSessionProvider);
    final profile = _profile;
    final orgName = (profile?['organizationName'] ?? 'Reseller').toString();
    final resellerId = (profile?['resellerId'] ?? session?.resellerId ?? '')
        .toString();
    final initial = orgName.trim().isEmpty
        ? 'R'
        : orgName.trim().substring(0, 1).toUpperCase();

    final rows = <MapEntry<String, String>>[
      MapEntry('Reseller ID', resellerId),
      MapEntry('Client ID', (profile?['clientId'] ?? '').toString()),
      MapEntry('Organization', orgName),
      MapEntry('Contact email', (profile?['contactEmail'] ?? '').toString()),
      MapEntry('Contact mobile', (profile?['contactMobile'] ?? '').toString()),
      MapEntry('City', (profile?['city'] ?? '').toString()),
      MapEntry('State', (profile?['state'] ?? '').toString()),
      MapEntry('PAN', (profile?['pan'] ?? '').toString()),
      MapEntry('GST', (profile?['gst'] ?? '').toString()),
      MapEntry('Status', (profile?['status'] ?? '').toString()),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF523DA9), Color(0xFF7357F1)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orgName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        if (resellerId.isNotEmpty)
                          Text(
                            resellerId,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F1F4)),
                  ),
                  child: Column(
                    children: rows
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    e.key,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: widget.onChangePassword,
                child: const Text('Change password'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF06DA6), Color(0xFF755FF0)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 17,
                    ),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
