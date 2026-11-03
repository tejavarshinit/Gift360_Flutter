import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/reseller/data/reseller_api.dart';
import 'package:gift360/features/reseller/data/reseller_store.dart';
import 'package:gift360/features/reseller/presentation/providers/reseller_provider.dart';

/// Reseller catalog: searchable, paginated brand products with a denomination /
/// amount picker and add-to-cart. Ported from React `pages/ResellerCatalog.tsx`.
class ResellerCatalogScreen extends ConsumerStatefulWidget {
  const ResellerCatalogScreen({super.key});

  @override
  ConsumerState<ResellerCatalogScreen> createState() =>
      _ResellerCatalogScreenState();
}

class _ResellerCatalogScreenState extends ConsumerState<ResellerCatalogScreen> {
  final _searchInput = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  String _search = '';
  int _page = 0;
  int _totalPages = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _loadTriggered = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchInput.dispose();
    super.dispose();
  }

  /// Infinite scroll: append the next page near the bottom (matches React).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 300) return;
    if (_loading || _loadingMore) return;
    if (_page + 1 >= _totalPages) return;
    _load(_page + 1, _search);
  }

  Future<void> _load(int pageToLoad, String query) async {
    if (pageToLoad == 0) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await ref.read(resellerApiProvider).searchProducts(
            search: query,
            page: pageToLoad,
            size: 20,
          );
      final rows = ((res['products'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() {
        _products = pageToLoad == 0 ? rows : [..._products, ...rows];
        _page = (res['page'] as num?)?.toInt() ?? pageToLoad;
        _totalPages = (res['totalPages'] as num?)?.toInt() ?? 0;
        _search = query;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ResellerApi.errorMessage(
            e,
            "Couldn't load the catalog. Please retry.",
          ));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _runSearch() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _load(0, _searchInput.text.trim());
  }

  void _clearSearch() {
    _searchInput.clear();
    if (_search.isNotEmpty) _load(0, '');
  }

  List<double> _denominations(Map<String, dynamic> p) =>
      ((p['denominations'] as List?) ?? const [])
          .whereType<num>()
          .map((e) => e.toDouble())
          .toList();

  double? _minPrice(Map<String, dynamic> p) => (p['minPrice'] as num?)?.toDouble();
  double? _maxPrice(Map<String, dynamic> p) => (p['maxPrice'] as num?)?.toDouble();

  String _priceLabel(Map<String, dynamic> p) {
    final denoms = _denominations(p);
    if (denoms.isNotEmpty) {
      final shown = denoms.take(3).map(_money).join(' • ');
      final more = denoms.length > 3 ? ' +${denoms.length - 3}' : '';
      return '$shown$more';
    }
    final min = _minPrice(p);
    final max = _maxPrice(p);
    if (min != null && max != null) return '${_money(min)} - ${_money(max)}';
    return 'Price unavailable';
  }

  String _money(double v) {
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '₹$s';
  }

  int _stockQty(Map<String, dynamic> p) {
    final s = int.tryParse((p['stockAvailable'] ?? '10').toString()) ?? 10;
    return s > 0 ? s : 10;
  }

  Future<void> _openAdd(Map<String, dynamic> product) async {
    final denoms = _denominations(product);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddToCartSheet(
        product: product,
        denominations: denoms,
        minPrice: _minPrice(product),
        maxPrice: _maxPrice(product),
        stockQty: _stockQty(product),
      ),
    );
    if (result == null) return;

    final unit = (result['unitPrice'] as num).toDouble();
    final qty = (result['quantity'] as num).toInt();
    final images = ((product['images'] as List?) ?? const []).map((e) => e.toString()).toList();
    ref.read(resellerCartProvider.notifier).add(
          ResellerCartItem(
            brandSku: (product['brandSku'] ?? '').toString(),
            brandName: (product['brandName'] ?? '').toString(),
            image: images.isNotEmpty ? images.first : null,
            unitPrice: unit,
            quantity: qty,
            discount: ((product['discount'] as num?)?.toDouble()) ?? 0,
          ),
          maxQuantity: _stockQty(product),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['brandName']} • ${_money(unit)} × $qty added to cart'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(resellerSessionProvider);
    final cartCount = ref.watch(resellerCartProvider).fold<int>(
          0,
          (sum, i) => sum + i.quantity,
        );

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Catalog')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/reseller/login'),
            child: const Text('Reseller login'),
          ),
        ),
      );
    }

    // Wait for the persisted session before the first API load.
    if (!_loadTriggered) {
      _loadTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(0, '');
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Catalog',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/reseller/cart'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF523DA9)),
            ),
            label: Text(
              'Cart',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF523DA9),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchInput,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: InputDecoration(
                      hintText: 'Search brands (e.g. Bata)',
                      hintStyle: GoogleFonts.poppins(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchInput.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _runSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF523DA9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.search, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(0, _search), child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Text(
          _search.isNotEmpty ? 'Nothing matches "$_search"' : 'Catalog is empty.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _products.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _buildProductCard(_products[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final images = ((p['images'] as List?) ?? const []).map((e) => e.toString()).toList();
    final discount = (p['discount'] as num?)?.toDouble() ?? 0;
    final denoms = _denominations(p);
    final pricable = denoms.isNotEmpty ||
        (_minPrice(p) != null && _maxPrice(p) != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F1F4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 62,
              height: 62,
              color: const Color(0xFFF3E8FF),
              child: images.isNotEmpty
                  ? Image.network(
                      images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.card_giftcard, color: Color(0xFF9747FF)),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.card_giftcard, color: Color(0xFF9747FF)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (p['brandName'] ?? '').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (discount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${discount.toStringAsFixed(0)}% off',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  (p['category'] ?? '').toString(),
                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceLabel(p),
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: pricable ? () => _openAdd(p) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF523DA9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(
                        'Add',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddToCartSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<double> denominations;
  final double? minPrice;
  final double? maxPrice;
  final int stockQty;

  const _AddToCartSheet({
    required this.product,
    required this.denominations,
    required this.minPrice,
    required this.maxPrice,
    required this.stockQty,
  });

  @override
  State<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends State<_AddToCartSheet> {
  double? _pickedDenom;
  final _amount = TextEditingController();
  int _qty = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.denominations.isNotEmpty) {
      _pickedDenom = widget.denominations.first;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? _unitPrice() {
    if (widget.denominations.isNotEmpty) return _pickedDenom;
    final v = double.tryParse(_amount.text.trim());
    if (v == null || v <= 0) return null;
    if (widget.minPrice != null && v < widget.minPrice!) return null;
    if (widget.maxPrice != null && v > widget.maxPrice!) return null;
    return v;
  }

  void _confirm() {
    final unit = _unitPrice();
    if (unit == null) {
      setState(() {
        _error = widget.minPrice != null && widget.maxPrice != null
            ? 'Enter an amount between ${_money(widget.minPrice!)} and ${_money(widget.maxPrice!)}'
            : 'Pick a denomination';
      });
      return;
    }
    Navigator.of(context).pop({'unitPrice': unit, 'quantity': _qty});
  }

  String _money(double v) =>
      '₹${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              (widget.product['brandName'] ?? '').toString(),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              (widget.product['category'] ?? '').toString(),
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 14),
            if (widget.denominations.isNotEmpty) ...[
              Text(
                'Choose denomination',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.denominations.map((d) {
                  final selected = _pickedDenom == d;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _pickedDenom = d;
                      _error = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF523DA9) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? const Color(0xFF523DA9) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        _money(d),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Text(
                'Enter amount',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: widget.minPrice != null && widget.maxPrice != null
                      ? '${_money(widget.minPrice!)} - ${_money(widget.maxPrice!)}'
                      : 'Amount',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Quantity',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                _qtyButton(Icons.remove, () {
                  if (_qty > 1) setState(() => _qty--);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_qty',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _qtyButton(Icons.add, () {
                  if (_qty < widget.stockQty) setState(() => _qty++);
                }),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF523DA9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Add to cart',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF374151)),
      ),
    );
  }
}
