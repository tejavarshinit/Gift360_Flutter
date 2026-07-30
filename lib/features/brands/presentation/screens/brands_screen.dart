import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/widgets/brand_voucher_modal.dart';
import 'package:gift360/features/payment/presentation/widgets/payment_details_sheet.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/data/models/payment.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/brands/presentation/providers/filter_meta_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/core/providers/notification_provider.dart';

class BrandsScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  final String? initialCategory;

  const BrandsScreen({super.key, this.initialSearch, this.initialCategory});

  @override
  ConsumerState<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends ConsumerState<BrandsScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  // Filter state
  List<String> _categories = [];
  List<String> _brands = [];
  String _priceRange = 'all';
  String _sortBy = 'Popularity';
  List<String> _discountRanges = [];
  bool _showFilterSidebar = false;

  // Voucher modal state
  bool _showVoucherModal = false;
  List<Brand> _vouchers = [];
  bool _voucherLoading = false;
  String? _voucherError;
  Brand? _selectedBrand;

  // Payment sheet state
  bool _showPaymentSheet = false;
  bool _paymentLoading = false;
  bool _paymentProcessing = false;
  String? _paymentError;
  Brand? _paymentBrand;

  // Scroll controllers for arrow navigation
  final ScrollController _scrollRow1 = ScrollController();
  final ScrollController _scrollRow2 = ScrollController();
  final ScrollController _scrollRow3 = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!;
    }
    if (widget.initialCategory != null) {
      _categories = [widget.initialCategory!];
    }
  }

  @override
  void didUpdateWidget(BrandsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory && widget.initialCategory != null) {
      setState(() => _categories = [widget.initialCategory!]);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollRow1.dispose();
    _scrollRow2.dispose();
    _scrollRow3.dispose();
    super.dispose();
  }

  int get _activeFiltersCount =>
      _categories.length +
      _brands.length +
      (_priceRange != 'all' ? 1 : 0) +
      _discountRanges.length;

  FilterKey _buildFilterKey() {
    final priceRange = _priceRangeValues(_priceRange);
    return FilterKey(
      categories: List.unmodifiable(_categories),
      brands: List.unmodifiable(_brands),
      minPrice: priceRange.$1,
      maxPrice: priceRange.$2,
      sortBy: _mapSortBy(_sortBy),
      discountRanges: List.unmodifiable(_discountRanges),
    );
  }

  (double?, double?) _priceRangeValues(String label) {
    switch (label) {
      case 'Under ₹50':
        return (null, 50);
      case '₹50 - ₹100':
        return (50, 100);
      case '₹100 - ₹250':
        return (100, 250);
      case '₹250+':
        return (250, null);
      case 'all':
      default:
        return (null, null);
    }
  }

  List<String> _deriveCategories(List<Brand> brands) {
    final categories = <String>{};
    for (final brand in brands) {
      final category = brand.category?.trim();
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }
    final list = categories.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _deriveBrands(List<Brand> brands) {
    final names = <String>{};
    for (final brand in brands) {
      final name = brand.brandName?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    final list = names.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _deriveDiscountRanges(List<Brand> brands) {
    final ranges = <String>{};
    for (final brand in brands) {
      final parsed = double.tryParse(brand.discount ?? '');
      if (parsed != null && parsed > 0) {
        ranges.add(parsed.toInt().toString());
      }
    }
    final list = ranges.toList();
    list.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return list;
  }

  String _mapSortBy(String displayName) {
    switch (displayName) {
      case 'Price: Low to High':
        return 'price-low';
      case 'Price: High to Low':
        return 'price-high';
      case 'Brand: A to Z':
        return 'brand-az';
      case 'Brand: Z to A':
        return 'brand-za';
      case 'Popularity':
      default:
        return 'popularity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFiltersCount = _activeFiltersCount;
    final filterBody = activeFiltersCount > 0 ? _buildFilterKey() : null;
    final allBrandsAsync = ref.watch(brandsProvider);
    final allBrands = allBrandsAsync.asData?.value ?? const <Brand>[];
    final brandsAsync = activeFiltersCount > 0 && filterBody != null
        ? ref.watch(filteredBrandsProvider(filterBody))
        : allBrandsAsync;

    return Scaffold(
      body: Stack(
        children: [
          // Aurora background
          Positioned.fill(
            child: _buildAuroraBackground(),
          ),
          // Main content
          Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              if (_categories.isNotEmpty || _brands.isNotEmpty || _discountRanges.isNotEmpty || _priceRange != 'all')
                _buildFilterChips(),
              Expanded(
                child: brandsAsync.when(
                  data: (brands) => _buildBrandsContent(brands),
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
                  error: (e, _) => _buildErrorState(),
                ),
              ),
            ],
          ),
          // Filter sidebar
          if (_showFilterSidebar)
            Consumer(
              builder: (context, ref, _) {
                final filterMetaAsync = ref.watch(filterMetaProvider);
                final filterMeta = filterMetaAsync.value;
                return _buildFilterModal(
                  availableCategories: filterMeta?.categories.isNotEmpty == true
                      ? filterMeta!.categories
                      : _deriveCategories(allBrands),
                  availableBrands: filterMeta?.brands.isNotEmpty == true
                      ? filterMeta!.brands
                      : _deriveBrands(allBrands),
                  availablePriceRanges: const ['All', 'Under ₹50', '₹50 - ₹100', '₹100 - ₹250', '₹250+'],
                  availableDiscountRanges: filterMeta?.discountRanges.map((d) => d.label).toList() ?? _deriveDiscountRanges(allBrands),
                  availableSortOptions: filterMeta?.sortOptions ?? const ['Popularity'],
                );
              },
            ),
          if (_showVoucherModal)
            BrandVoucherModal(
              isOpen: _showVoucherModal,
              brandName: _selectedBrand?.brandName ?? '',
              vouchers: _vouchers,
              loading: _voucherLoading,
              error: _voucherError,
              onClose: () => setState(() => _showVoucherModal = false),
              onRetry: () => _fetchVouchers(_selectedBrand),
              onVoucherSelect: (voucher) {
                setState(() {
                  _showVoucherModal = false;
                  _paymentBrand = null;
                  _paymentLoading = true;
                  _paymentError = null;
                  _showPaymentSheet = true;
                });
                _fetchPaymentDetails(voucher);
              },
            ),
          if (_showPaymentSheet)
            PaymentDetailsSheet(
              brand: _paymentBrand,
              loading: _paymentLoading,
              processing: _paymentProcessing,
              error: _paymentError,
              onClose: () => setState(() {
                _showPaymentSheet = false;
                _paymentLoading = false;
                _paymentProcessing = false;
                _paymentError = null;
                _paymentBrand = null;
              }),
              onAddToCart: (brand, amount, quantity) {
                ref.read(cartProvider.notifier).addToCart(AddToCartRequest(
                      brandId: brand.brandId ?? '',
                      brandName: brand.brandName ?? '',
                      quantity: quantity,
                      unitValue: amount,
                      image: brand.resolvedImageUrl,
                    ));
                ref.read(notificationProvider.notifier).addNotification(
                      title: 'Added to Cart',
                      message: '${brand.brandName} voucher has been added successfully into cart',
                      type: 'success',
                    );
                setState(() {
                  _showPaymentSheet = false;
                  _paymentLoading = false;
                  _paymentProcessing = false;
                  _paymentError = null;
                  _paymentBrand = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${quantity}x ${brand.brandName} voucher(s) of ₹${amount.toInt()} added to cart')),
                );
              },
              onPay: (brand, amount, quantity) => _handlePay(brand, amount, quantity),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Aurora Background (Section 2)
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
          // Amber glow blob top-left
          Positioned(
            top: -128,
            left: -96,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              ),
            ),
          ),
          // Yellow glow blob right-center
          Positioned(
            top: MediaQuery.of(context).size.height * 0.33,
            right: -96,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFACC15).withValues(alpha: 0.08),
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
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  'All Brands',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF101010),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Search + Filter Row (Section 4B)
  // ─────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (v) => setState(() => _showSuggestions = true),
                    onTap: () => setState(() => _showSuggestions = true),
                    onSubmitted: (_) {
                      setState(() => _showSuggestions = false);
                      _searchFocusNode.unfocus();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search brands...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12, right: 4),
                        child: Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(),
            ],
          ),
          if (_showSuggestions) _buildSuggestions(),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: () => setState(() => _showFilterSidebar = true),
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
          if (_activeFiltersCount > 0)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$_activeFiltersCount',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6C5CE7),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Search Suggestions (Section 4C)
  // ─────────────────────────────────────────────
  Widget _buildSuggestions() {
    return Consumer(
      builder: (context, ref, _) {
        final brandsAsync = ref.watch(brandsProvider);
        return brandsAsync.when(
          data: (brands) {
            final query = _searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? brands.take(8).toList()
                : brands.where((b) => (b.brandName ?? '').toLowerCase().contains(query)).take(8).toList();
            if (filtered.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: filtered.map((brand) {
                  return InkWell(
                    onTap: () {
                      _onBrandTap(brand);
                      setState(() => _showSuggestions = false);
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brand.brandName ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (brand.category != null && brand.category!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              brand.category!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Filter Chips (Section 4D)
  // ─────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ..._categories.map((cat) => _buildChip(cat, () => setState(() => _categories = []))),
          ..._brands.map((b) => _buildChip(b, () => setState(() => _brands = []))),
          ..._discountRanges.map((dr) => _buildChip('$dr%+', () => setState(() => _discountRanges = []))),
          if (_priceRange != 'all') _buildChip(_priceRange, () => setState(() => _priceRange = 'all')),
        ],
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF7C3AED)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Brands Content (Section 4E)
  // ─────────────────────────────────────────────
  Widget _buildBrandsContent(List<Brand> brands) {
    final query = _searchController.text.trim().toLowerCase();
    var displayBrands = brands;
    if (query.isNotEmpty) {
      displayBrands = displayBrands
          .where((b) => (b.brandName ?? '').toLowerCase().contains(query))
          .toList();
    }

    if (displayBrands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty ? 'No brands found for "$query"' : 'No brands available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Split into 3 rows
    final row1 = <Brand>[];
    final row2 = <Brand>[];
    final row3 = <Brand>[];
    for (int i = 0; i < displayBrands.length; i++) {
      if (i % 3 == 0) {
        row1.add(displayBrands[i]);
      } else if (i % 3 == 1) {
        row2.add(displayBrands[i]);
      } else {
        row3.add(displayBrands[i]);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results count
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Showing ',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  TextSpan(
                    text: '${displayBrands.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  TextSpan(
                    text: ' brands',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Section header + arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Brands',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF101010),
                ),
              ),
              Row(
                children: [
                  _buildArrowButton(
                    Icons.chevron_left,
                    () => _scrollRow1.jumpTo(
                      (_scrollRow1.offset - 200).clamp(0.0, _scrollRow1.position.maxScrollExtent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildArrowButton(
                    Icons.chevron_right,
                    () => _scrollRow1.jumpTo(
                      (_scrollRow1.offset + 200).clamp(0.0, _scrollRow1.position.maxScrollExtent),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 3 rows of brand cards
          if (row1.isNotEmpty) _buildBrandScrollRow(row1, _scrollRow1),
          const SizedBox(height: 12),
          if (row2.isNotEmpty) _buildBrandScrollRow(row2, _scrollRow2),
          const SizedBox(height: 12),
          if (row3.isNotEmpty) _buildBrandScrollRow(row3, _scrollRow3),
        ],
      ),
    );
  }

  Widget _buildArrowButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF6C5CE7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Brand Scroll Row (Section 4F)
  // ─────────────────────────────────────────────
  Widget _buildBrandScrollRow(List<Brand> brands, ScrollController controller) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        controller: controller,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 0),
        itemCount: brands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildBrandCard(brands[index]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Brand Card (Section 4G)
  // ─────────────────────────────────────────────
  Widget _buildBrandCard(Brand brand) {
    final imageUrl = brand.resolvedImageUrl;
    final brandName = brand.brandName ?? '';

    return GestureDetector(
      onTap: () => _onBrandTap(brand),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111827).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: imageUrl != null
                  ? BrandImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, s) => const SizedBox(),
                      errorWidget: (_, s, e) => const Icon(Icons.store, color: Color(0xFF94A3B8)),
                    )
                  : const Icon(Icons.store, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 6),
            Text(
              brandName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Filter Modal (Section 5) — Full Screen
  // ─────────────────────────────────────────────
  Widget _buildFilterModal({
    required List<String> availableCategories,
    required List<String> availableBrands,
    required List<String> availablePriceRanges,
    required List<String> availableDiscountRanges,
    List<String> availableSortOptions = const ['Popularity'],
  }) {
    return GestureDetector(
      onTap: () => setState(() => _showFilterSidebar = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: GestureDetector(
          onTap: () {},
          child: SafeArea(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters & Sort',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _showFilterSidebar = false),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reset All
                          _buildResetAllButton(),
                          const SizedBox(height: 16),
                          // Sort By
                          _buildFilterAccordion(
                            title: 'Sort By',
                            initiallyExpanded: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Sort Brands'),
                                ...availableSortOptions.map((option) =>
                                  _buildRadioOption(option, option, _sortBy, (v) => setState(() => _sortBy = v)),
                                ),
                                const SizedBox(height: 12),
                                _buildSectionLabel('Discount'),
                                _buildRadioOption('High to Low', 'discount-high-low', _sortBy, (v) => setState(() => _sortBy = v)),
                                _buildRadioOption('Low to High', 'discount-low-high', _sortBy, (v) => setState(() => _sortBy = v)),
                              ],
                            ),
                          ),
                          // Filter By heading
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Filter By',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Price Range
                          _buildFilterAccordion(
                            title: 'Price Range',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRadioOption('All Prices', 'all', _priceRange, (v) => setState(() => _priceRange = v)),
                                ...availablePriceRanges.where((l) => l != 'All').map(
                                  (label) => _buildRadioOption(label, label, _priceRange, (v) => setState(() => _priceRange = v)),
                                ),
                              ],
                            ),
                          ),
                          // Discount Ranges
                          _buildFilterAccordion(
                            title: 'Discount Ranges',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: availableDiscountRanges.map((d) =>
                                _buildCheckboxOption(d, _discountRanges.contains(d), (v) {
                                  setState(() {
                                    if (v) {
                                      _discountRanges.add(d);
                                    } else {
                                      _discountRanges.remove(d);
                                    }
                                  });
                                }),
                              ).toList(),
                            ),
                          ),
                          // Categories
                          _buildFilterAccordion(
                            title: 'Categories',
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 256),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: availableCategories.length,
                                itemBuilder: (_, i) => _buildRadioOption(
                                  availableCategories[i],
                                  availableCategories[i],
                                  _categories.isNotEmpty ? _categories.first : '',
                                  (v) => setState(() {
                                    _categories = [v];
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _showFilterSidebar = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Apply Filters',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetAllButton() {
    return GestureDetector(
      onTap: () => setState(() {
        _categories = [];
        _brands = [];
        _priceRange = 'all';
        _sortBy = 'Popularity';
        _discountRanges = [];
      }),
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Reset All',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF101010),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAccordion({
    required String title,
    bool initiallyExpanded = false,
    required Widget child,
  }) {
    return _FilterAccordion(
      title: title,
      initiallyExpanded: initiallyExpanded,
      child: child,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF101010),
        ),
      ),
    );
  }

  Widget _buildRadioOption(String label, String value, String groupValue, ValueChanged<String> onChanged) {
    final isSelected = value == groupValue;
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: groupValue,
          activeColor: const Color(0xFF6C5CE7),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF101010),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxOption(String label, bool isChecked, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Checkbox(
          value: isChecked,
          activeColor: const Color(0xFF6C5CE7),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) => onChanged(v ?? false),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF101010),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Brand Tap, Voucher, Payment logic (UNCHANGED)
  // ─────────────────────────────────────────────
  void _onBrandTap(Brand brand) async {
    String resolvedId = brand.brandId ?? '';
    try {
      final api = ref.read(brandsApiProvider);
      final allBrands = await api.getBrands();
      resolvedId = _resolveCanonicalBrandId(brand, allBrands) ?? resolvedId;
    } catch (_) {}

    final resolved = brand.copyWith(brandId: resolvedId);
    setState(() {
      _selectedBrand = resolved;
      _showVoucherModal = true;
      _voucherLoading = true;
      _voucherError = null;
      _vouchers = [];
    });
    _fetchVouchers(resolved);
  }

  String? _resolveCanonicalBrandId(Brand brand, List<Brand> allBrands) {
    String normalize(String? s) => (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

    final name = normalize(brand.brandName);
    final category = normalize(brand.category);
    final code = normalize(brand.brandCode);

    for (final c in allBrands) {
      if (normalize(c.brandName) == name && (category.isEmpty || normalize(c.category) == category)) {
        return c.brandId;
      }
    }
    for (final c in allBrands) {
      if (normalize(c.brandName) == name) return c.brandId;
    }
    if (code.isNotEmpty) {
      for (final c in allBrands) {
        if (normalize(c.brandCode) == code) return c.brandId;
      }
    }
    for (final c in allBrands) {
      final cName = normalize(c.brandName);
      if (cName.isNotEmpty && name.isNotEmpty && (cName.contains(name) || name.contains(cName))) {
        return c.brandId;
      }
    }
    return brand.brandId;
  }

  Future<void> _fetchVouchers(Brand? brand) async {
    if (brand == null) return;
    try {
      final api = ref.read(brandsApiProvider);
      final details = await api.getBrandVoucherList(brand.brandId ?? '');
      if (!mounted) return;

      // For vouchers with minPrice=0 and no denominationList, fetch full details
      final enriched = <Brand>[];
      for (final voucher in details) {
        final needsDetails = (voucher.minPrice == null || voucher.minPrice == 0) &&
            (voucher.maxPrice == null || voucher.maxPrice == 0) &&
            (voucher.denominationList == null || voucher.denominationList!.isEmpty);
        if (needsDetails && voucher.brandId != null && voucher.brandId!.isNotEmpty) {
          try {
            final full = await api.getBrandById(voucher.brandId!);
            enriched.add(full);
          } catch (_) {
            enriched.add(voucher);
          }
        } else {
          enriched.add(voucher);
        }
      }

      if (!mounted) return;
      setState(() {
        _vouchers = enriched;
        _voucherLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voucherError = e.toString();
        _voucherLoading = false;
      });
    }
  }

  Future<void> _fetchPaymentDetails(Brand voucher) async {
    final brandId = voucher.brandId ?? '';
    if (brandId.isEmpty) {
      setState(() {
        _paymentError = 'Brand details not available';
        _paymentLoading = false;
      });
      return;
    }
    try {
      final api = ref.read(brandsApiProvider);
      final details = await api.getBrandById(brandId);
      if (!mounted) return;
      setState(() {
        _paymentBrand = details;
        _paymentError = null;
        _paymentLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentError = e.toString();
        _paymentLoading = false;
      });
    }
  }

  Future<void> _handlePay(Brand brand, double amount, int quantity) async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to make a payment')),
      );
      return;
    }

    final totalAmount = amount * quantity;
    final brandId = brand.brandId ?? '';
    if (brandId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand ID not available')),
      );
      return;
    }

    setState(() => _paymentProcessing = true);
    final paymentNotifier = ref.read(paymentProvider.notifier);

    try {
      final orderNumber = await paymentNotifier.createOrder(
        clientId: user.clientId,
        items: [
          {
            'brandId': brandId,
            'quantity': quantity,
            'unitValue': amount,
            'lineTotal': totalAmount,
            'meta': '{}',
          },
        ],
        totalAmount: totalAmount,
      );
      if (!mounted) return;
      if (orderNumber == null) {
        final err = ref.read(paymentProvider).error ?? 'Failed to create order';
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      final valid = await paymentNotifier.validateOrder(
        cartTotal: totalAmount,
        walletAmount: 0,
        walletUsed: false,
      );
      if (!mounted) return;
      if (!valid) {
        final err = ref.read(paymentProvider).error ?? 'Order validation failed';
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      final tokenOk = await paymentNotifier.generateToken();
      if (!mounted) return;
      if (!tokenOk) {
        final err = ref.read(paymentProvider).error ?? 'Failed to generate payment token';
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      final encryptedOrderRef = encryptOrderRef(orderNumber, user.clientId);
      final initiated = await paymentNotifier.initiatePayment(
        amount: totalAmount,
        productInfo: AppConfig.paymentProductInfo,
        frontendUrl: AppConfig.sabbpeFrontendUrl,
        customer: CustomerInfo(
          firstname: AppConfig.paymentCustFirstName,
          email: AppConfig.paymentCustEmail,
          phone: AppConfig.paymentCustMobile,
        ),
        encryptedOrderRef: encryptedOrderRef,
        clientId: user.clientId,
      );
      if (!mounted) return;
      if (!initiated) {
        final err = ref.read(paymentProvider).error ?? 'Payment initiation failed';
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      final initiateResponse = ref.read(paymentProvider).initiateResponse;
      final paymentUrl = initiateResponse?.paymentUrl;
      if (paymentUrl == null || paymentUrl.isEmpty) {
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment URL not received from gateway')),
        );
        return;
      }

      setState(() {
        _paymentProcessing = false;
        _showPaymentSheet = false;
        _paymentBrand = null;
      });

      context.push('/payment-webview', extra: {
        'paymentUrl': paymentUrl,
        'orderNumber': orderNumber,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: ${e.toString()}')),
      );
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          const Text('Failed to load brands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Please try again later', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(brandsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Filter Accordion Widget (Section 5A)
// ─────────────────────────────────────────────
class _FilterAccordion extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final Widget child;

  const _FilterAccordion({
    required this.title,
    this.initiallyExpanded = false,
    required this.child,
  });

  @override
  State<_FilterAccordion> createState() => _FilterAccordionState();
}

class _FilterAccordionState extends State<_FilterAccordion> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Color(0xFFE5E7EB), height: 1),
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF101010),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: widget.child,
          ),
      ],
    );
  }
}
