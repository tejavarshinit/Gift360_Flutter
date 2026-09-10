import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/filter_meta_provider.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/payment/presentation/widgets/payment_details_sheet.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/data/models/payment.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/core/providers/notification_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});
  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _showPaymentSheet = false;
  Brand? _paymentBrand;
  bool _paymentLoading = false;
  String? _paymentError;

  // Filter state — matches React CategoryFilterState exactly
  List<String> _selectedCategories = [];
  String _priceRangeLabel = 'all';
  List<String> _selectedDiscountRanges = [];
  String _sortOrder = 'none';
  bool _showFilterSheet = false;

  // Expandable sections in filter
  bool _sortExpanded = true;
  bool _categoryExpanded = false;
  bool _priceExpanded = false;
  bool _discountExpanded = false;

  final Map<String, bool> _expandedCategories = {};

  void _openBuySheet(String brandId) {
    setState(() {
      _paymentBrand = null;
      _paymentLoading = true;
      _paymentError = null;
      _showPaymentSheet = true;
    });
    _fetchBrandDetails(brandId);
  }

  Future<void> _fetchBrandDetails(String brandId) async {
    try {
      final api = ref.read(brandsApiProvider);
      final details = await api.getBrandById(brandId);
      if (!mounted) return;
      setState(() { _paymentBrand = details; _paymentLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _paymentError = e.toString(); _paymentLoading = false; });
    }
  }

  Future<void> _handlePay(Brand brand, double amount, int quantity) async {
    final user = ref.read(authProvider);
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in')));
      return;
    }
    final brandId = brand.brandId ?? '';
    if (brandId.isEmpty) return;
    setState(() { _showPaymentSheet = false; _paymentBrand = null; });
    final totalAmount = amount * quantity;
    final pn = ref.read(paymentProvider.notifier);
    try {
      final orderNumber = await pn.createOrder(
        clientId: user.clientId,
        items: [
          {
            'brandId': brandId,
            'quantity': quantity,
            'unitValue': amount,
            'lineTotal': totalAmount,
            'meta': jsonEncode({
              'brand_id': brandId,
              'brand_name': brand.brandName,
              'image_url': brand.resolvedImageUrl,
              'redeem_steps': <String>[],
            }),
          },
        ],
        totalAmount: totalAmount,
      );
      if (!mounted || orderNumber == null) return;
      final valid = await pn.validateOrder(cartTotal: totalAmount, walletAmount: 0, walletUsed: false);
      if (!mounted || !valid) return;
      // Backend-mediated payment initiation (backend computes net payable).
      final paymentResponse = await pn.initiateBackendPayment();
      if (!mounted || paymentResponse == null) return;
      final url = paymentResponse['payment_url'] ?? paymentResponse['paymentUrl'];
      if (url != null && url.toString().isNotEmpty && mounted) {
        context.push('/payment-webview', extra: {'paymentUrl': url.toString(), 'orderNumber': orderNumber});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e')));
    }
  }

  // ── Filter logic (matches React exactly) ──

  List<Brand> _applyFilters(List<Brand> brands, FilterMeta? meta) {
    var result = brands;

    // Category filter (single-select)
    if (_selectedCategories.isNotEmpty) {
      final selectedCategory = _selectedCategories[0];
      result = result.where((b) => (b.category ?? '') == selectedCategory).toList();
    }

    if (_priceRangeLabel != 'all' && meta?.priceRanges != null) {
      final sel = meta!.priceRanges.firstWhere((r) => r.label == _priceRangeLabel, orElse: () => const PriceRange(label: ''));
      if (sel.label.isNotEmpty) {
        final min = sel.min ?? double.negativeInfinity;
        final max = sel.max ?? double.infinity;
        result = result.where((b) => (b.minPrice ?? double.negativeInfinity) <= max && (b.maxPrice ?? double.infinity) >= min).toList();
      }
    }

    if (_selectedDiscountRanges.isNotEmpty && meta?.discountRanges != null) {
      result = result.where((brand) {
        final dv = double.tryParse(brand.discount ?? '0') ?? 0;
        return _selectedDiscountRanges.any((rk) {
          final r = meta!.discountRanges.firstWhere(
            (d) => (d.value?.trim().isNotEmpty == true ? d.value!.trim() : d.label) == rk,
            orElse: () => const DiscountRange(label: '', value: ''),
          );
          final bounds = _inferDiscountBounds(r.value?.isNotEmpty == true ? r.value! : r.label);
          return dv >= bounds.$1 && dv <= bounds.$2;
        });
      }).toList();
    }

    return result;
  }

  List<Brand> _sortBrands(List<Brand> brands) {
    final s = List<Brand>.from(brands);
    int cmp(Brand a, Brand b) {
      final na = (a.brandName ?? '').trim();
      final nb = (b.brandName ?? '').trim();
      final nA = RegExp(r'^\d').hasMatch(na);
      final nB = RegExp(r'^\d').hasMatch(nb);
      if (nA && !nB) return 1;
      if (!nA && nB) return -1;
      return na.compareTo(nb);
    }
    switch (_sortOrder) {
      case 'a-z': s.sort(cmp); break;
      case 'z-a': s.sort((a, b) => cmp(b, a)); break;
      case 'discount-high-low': s.sort((a, b) => (double.tryParse(b.discount ?? '0') ?? 0).compareTo(double.tryParse(a.discount ?? '0') ?? 0)); break;
      case 'discount-low-high': s.sort((a, b) => (double.tryParse(a.discount ?? '0') ?? 0).compareTo(double.tryParse(b.discount ?? '0') ?? 0)); break;
      default: s.sort(cmp); break;
    }
    return s;
  }

  (double, double) _inferDiscountBounds(String raw) {
    final n = raw.trim().toLowerCase();
    final nums = RegExp(r'(\d+(?:\.\d+)?)').allMatches(n).map((m) => double.parse(m.group(0)!)).toList();
    if (nums.length >= 2 && RegExp(r'-|to|through|upto').hasMatch(n)) {
      return (nums[0] < nums[1] ? nums[0] : nums[1], nums[0] < nums[1] ? nums[1] : nums[0]);
    }
    if (nums.length == 1) {
      if (RegExp(r'\b(up to|under|below|less than|max|maximum)\b').hasMatch(n)) return (0, nums[0]);
      if (RegExp(r'\b(above|over|more than|greater than|min|minimum|at least)\b').hasMatch(n) || n.endsWith('+') || n.contains('plus')) return (nums[0], 99999);
      return (nums[0], nums[0]);
    }
    return (0, 99999);
  }

  bool _hasActiveFilters() {
    return _selectedCategories.isNotEmpty || _priceRangeLabel != 'all' || _selectedDiscountRanges.isNotEmpty || _sortOrder != 'none';
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategories = [];
      _priceRangeLabel = 'all';
      _selectedDiscountRanges = [];
      _sortOrder = 'none';
    });
  }

  int get _activeFilterCount {
    int c = 0;
    if (_selectedCategories.isNotEmpty) c++;
    if (_priceRangeLabel != 'all') c++;
    c += _selectedDiscountRanges.length;
    return c;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(allBrandsProvider);
    final filterMetaAsync = ref.watch(filterMetaProvider);
    final meta = filterMetaAsync.valueOrNull;

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/images/ganeshbackdrop.png', fit: BoxFit.cover)),
        Column(children: [
          _buildHeader(),
          Expanded(child: brandsAsync.when(
            data: (brands) {
              final filtered = _applyFilters(brands, meta);
              final sorted = _sortBrands(filtered);
              return _buildCategoryList(sorted, brands);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
            error: (e, _) => Center(child: Text('Error: $e')),
          )),
        ]),
        if (_showPaymentSheet) PaymentDetailsSheet(
          brand: _paymentBrand, loading: _paymentLoading, processing: false, error: _paymentError,
          onClose: () => setState(() { _showPaymentSheet = false; _paymentBrand = null; _paymentLoading = false; _paymentError = null; }),
          onAddToCart: (brand, amount, quantity) async {
            ref.read(cartProvider.notifier).addToCart(AddToCartRequest(brandId: brand.brandId!, brandName: brand.brandName ?? '', quantity: quantity, unitValue: amount, image: brand.resolvedImageUrl));
            ref.read(notificationProvider.notifier).addNotification(title: 'Added to Cart', message: '${brand.brandName} voucher added to cart', type: 'success');
            setState(() { _showPaymentSheet = false; _paymentBrand = null; });
            await Future.delayed(const Duration(milliseconds: 2200));
            if (mounted) StatefulNavigationShell.of(context).goBranch(3);
          },
          onPay: (brand, amount, quantity) => _handlePay(brand, amount, quantity),
        ),
        if (_showFilterSheet) _buildFilterSheet(meta),
      ]),
    );
  }

  Widget _buildHeader() {
    return SafeArea(bottom: false, child: Container(
      width: double.infinity, height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1))),
      child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context), child: const SizedBox(width: 40, height: 40, child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1A1A1A)))),
        Expanded(child: Align(alignment: Alignment.center, child: Text('Categories', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
        GestureDetector(
          onTap: () => setState(() => _showFilterSheet = true),
          child: SizedBox(width: 40, height: 40, child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.tune, size: 20, color: Color(0xFF1A1A1A)),
            if (_activeFilterCount > 0) Positioned(top: 4, right: 4, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Color(0xFF6C5CE7), shape: BoxShape.circle), child: Center(child: Text('$_activeFilterCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))))),
          ])),
        ),
      ]),
    ));
  }

  Widget _buildCategoryList(List<Brand> filteredBrands, List<Brand> allBrands) {
    final filterMetaAsync = ref.watch(filterMetaProvider);
    final categoryNames = filterMetaAsync.when(
      data: (m) => m.categories.isNotEmpty ? m.categories : _extractCategories(allBrands),
      loading: () => _extractCategories(allBrands),
      error: (_, __) => _extractCategories(allBrands),
    );
    final categoryMap = <String, List<Brand>>{};
    for (final b in filteredBrands) { categoryMap.putIfAbsent(b.category ?? 'Other', () => []).add(b); }
    final active = _selectedCategories.isNotEmpty
        ? categoryNames.where((c) => c == _selectedCategories[0]).toList()
        : categoryNames.where((c) => (categoryMap[c]?.isNotEmpty ?? false)).toList();
    if (active.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No brands match the selected filters.', style: TextStyle(color: Colors.grey))));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96), itemCount: active.length,
      itemBuilder: (ctx, i) => _buildCategorySection(active[i], categoryMap[active[i]] ?? []),
    );
  }

  List<String> _extractCategories(List<Brand> brands) {
    final c = <String>{};
    for (final b in brands) { final cat = b.category?.trim(); if (cat != null && cat.isNotEmpty) c.add(cat); }
    return c.toList()..sort();
  }

  Widget _buildCategorySection(String title, List<Brand> brands) {
    final expanded = _expandedCategories[title] ?? false;
    final display = expanded ? brands : brands.take(8).toList();
    return Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827)))),
        if (!expanded)
          SizedBox(height: 130, child: ListView.separated(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: display.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (ctx, i) => _buildProductCard(display[i])))
        else
          // Matches React: "View all" expands to a multi-column wrap grid of cards.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brands.map((b) => SizedBox(width: (MediaQuery.of(context).size.width - 32 - 16) / 3, child: _buildProductCard(b))).toList(),
          ),
        if (brands.length > 8) GestureDetector(onTap: () => setState(() => _expandedCategories[title] = !expanded), child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(expanded ? 'Show less' : 'View all (${brands.length})', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6C5CE7))))),
      ],
    ));
  }

  Widget _buildProductCard(Brand brand) {
    final img = brand.resolvedImageUrl;
    final name = brand.brandName ?? '';
    final price = brand.effectiveStartingPrice;
    return Container(width: 120, height: 130, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2), spreadRadius: -1)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), clipBehavior: Clip.antiAlias,
            child: img != null ? BrandImage(imageUrl: img, fit: BoxFit.contain, placeholder: (_, __) => const SizedBox(), errorWidget: (_, __, ___) => const SizedBox()) : const SizedBox()),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('E-Gift Card', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400, color: const Color(0xFF9CA3AF))),
          ])),
        ]),
        Divider(color: AppColors.divider, thickness: 1, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(price > 0 ? '₹${price.toInt()}' : '-', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
          GestureDetector(onTap: () { if (brand.brandId?.isNotEmpty == true) _openBuySheet(brand.brandId!); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: AppColors.buyButtonGradient, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]),
              child: Text('Buy', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)))),
        ]),
      ]),
    );
  }

  // ── Filter Sheet (matches React FilterSidebar mobile layout exactly) ──

  Widget _buildFilterSheet(FilterMeta? meta) {
    return GestureDetector(
      onTap: () => setState(() => _showFilterSheet = false),
      child: Container(color: Colors.black54, child: GestureDetector(
        onTap: () {},
        child: Align(alignment: Alignment.centerRight, child: Container(
          width: MediaQuery.of(context).size.width * 0.85, height: double.infinity,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.horizontal(left: Radius.circular(20))),
          child: Column(children: [
            // Header
            Container(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Filters & Sort', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => setState(() => _showFilterSheet = false), icon: const Icon(Icons.close, size: 22)),
              ]),
            ),
            Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
              // Reset All
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _clearAllFilters, child: Text('Reset All', style: GoogleFonts.poppins()))),
              const SizedBox(height: 8),

              // ── Sort By Section ──
              _buildExpandableSection('Sort By', _sortExpanded, () => setState(() => _sortExpanded = !_sortExpanded), Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sort Brands', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                  _buildRadio('A to Z', 'a-z', _sortOrder, (v) => setState(() => _sortOrder = v)),
                  _buildRadio('Z to A', 'z-a', _sortOrder, (v) => setState(() => _sortOrder = v)),
                  const SizedBox(height: 12),
                  Text('Discount', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                  _buildRadio('High to Low', 'discount-high-low', _sortOrder, (v) => setState(() => _sortOrder = v)),
                  _buildRadio('Low to High', 'discount-low-high', _sortOrder, (v) => setState(() => _sortOrder = v)),
                ],
              )),

              // Filter By header
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Filter By', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF111827)))),

              // ── Categories Section ──
              if (meta?.categories != null && meta!.categories.isNotEmpty)
                _buildExpandableSection('Categories', _categoryExpanded, () => setState(() => _categoryExpanded = !_categoryExpanded),
                  Wrap(spacing: 8, runSpacing: 8, children: meta.categories.map((cat) {
                    final selected = _selectedCategories.contains(cat);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedCategories = [];
                        } else {
                          _selectedCategories = [cat];
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF6C5CE7) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? const Color(0xFF6C5CE7) : Colors.transparent),
                        ),
                        child: Text(cat, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : const Color(0xFF374151))),
                      ),
                    );
                  }).toList()),
                ),

              // ── Price Range Section ──
              if (meta?.priceRanges != null && meta!.priceRanges.isNotEmpty)
                _buildExpandableSection('Price Range', _priceExpanded, () => setState(() => _priceExpanded = !_priceExpanded),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildRadio('All Prices', 'all', _priceRangeLabel, (v) => setState(() => _priceRangeLabel = v)),
                    ...meta.priceRanges.map((r) => _buildRadio(r.label, r.label, _priceRangeLabel, (v) => setState(() => _priceRangeLabel = v))),
                  ]),
                ),

              // ── Discount Ranges Section ──
              if (meta?.discountRanges != null && meta!.discountRanges.isNotEmpty)
                _buildExpandableSection('Discount Ranges', _discountExpanded, () => setState(() => _discountExpanded = !_discountExpanded),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ...meta.discountRanges.map((dr) {
                      final key = dr.value?.trim().isNotEmpty == true ? dr.value!.trim() : dr.label;
                      final sel = _selectedDiscountRanges.contains(key);
                      return InkWell(onTap: () => setState(() {
                        if (sel) { _selectedDiscountRanges.remove(key); } else { _selectedDiscountRanges.add(key); }
                      }), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                        Checkbox(value: sel, onChanged: (_) => setState(() { if (sel) { _selectedDiscountRanges.remove(key); } else { _selectedDiscountRanges.add(key); } }), activeColor: const Color(0xFF6C5CE7)),
                        const SizedBox(width: 8),
                        Text(dr.label, style: GoogleFonts.poppins(fontSize: 13)),
                      ])));
                    }),
                  ]),
                ),
            ])),
            // Apply button
            Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
              child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () => setState(() => _showFilterSheet = false),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Apply Filters', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              )),
            ),
          ]),
        )),
      )),
    );
  }

  Widget _buildExpandableSection(String title, bool expanded, VoidCallback onTap, Widget child) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: onTap, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
          ]),
        )),
        if (expanded) Padding(padding: const EdgeInsets.only(bottom: 14), child: child),
      ]),
    );
  }

  Widget _buildRadio(String label, String value, String groupValue, ValueChanged<String> onChanged) {
    return RadioListTile<String>(
      value: value, groupValue: groupValue, onChanged: (v) { if (v != null) onChanged(v); },
      title: Text(label, style: GoogleFonts.poppins(fontSize: 13)),
      activeColor: const Color(0xFF6C5CE7), contentPadding: EdgeInsets.zero, dense: true,
    );
  }
}
