import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/brands/presentation/providers/brand_names_provider.dart';
import 'package:gift360/features/brands/presentation/providers/top_brands_provider.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/data/models/brand_name.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/home/presentation/widgets/instant_gifting_banner.dart';
import 'package:gift360/features/home/presentation/providers/recently_used_provider.dart';
import 'package:gift360/features/home/data/repositories/recently_used_api.dart';
import 'package:gift360/features/brands/presentation/providers/filter_meta_provider.dart';
import 'package:gift360/features/brands/presentation/widgets/brand_voucher_modal.dart';
import 'package:gift360/features/payment/presentation/widgets/payment_details_sheet.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/data/models/payment.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/core/providers/notification_provider.dart';
import 'package:gift360/config/app_config.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  bool _balanceVisible = true;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  bool _showPaymentSheet = false;
  bool _paymentLoading = false;
  bool _paymentProcessing = false;
  String? _paymentError;
  Brand? _paymentBrand;

  bool _showVoucherModal = false;
  bool _voucherLoading = false;
  String? _voucherError;
  Brand? _selectedBrand;
  List<Brand> _vouchers = [];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -10)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_floatController);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final walletAsync = ref.watch(walletBalanceProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _searchFocusNode.unfocus(),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HomeHeader + BalanceCard (overlapping, matches React reference) ──
                _buildHeaderSection(user, walletAsync, screenWidth),

                // ── ActionGrid ──
                _buildActionGrid(),

                // ── SearchSection ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 18, 21, 0),
                  child: _buildSearchBar(),
                ),

                // ── PromoCard ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 18, 21, 0),
                  child: InstantGiftingBanner(
                    onExplore: () => context.push('/brands'),
                  ),
                ),

                // ── RecommendedList ──
                _RecommendedSection(onBuy: _openPaymentSheet),

                // ── TopBrandsGrid ──
                _TopBrandsSection(onBrandTap: _openTopBrandModal),

                // ── RecentlyUsed ──
                _RecentlyUsedSection(),

                const SizedBox(height: 84),
              ],
            ),
          ),
        ),
        if (_showVoucherModal)
          BrandVoucherModal(
            isOpen: _showVoucherModal,
            brandName: _selectedBrand?.brandName ?? '',
            vouchers: _vouchers,
            loading: _voucherLoading,
            error: _voucherError,
            onClose: () => setState(() {
              _showVoucherModal = false;
              _selectedBrand = null;
              _vouchers = [];
            }),
            onRetry: () => _fetchVouchers(_selectedBrand?.brandId ?? ''),
            onVoucherSelect: (voucher) {
              setState(() {
                _showVoucherModal = false;
                _selectedBrand = null;
                _vouchers = [];
                _showPaymentSheet = true;
                _paymentBrand = null;
                _paymentLoading = true;
                _paymentError = null;
              });
              _fetchPaymentDetailsForVoucher(voucher);
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
            onAddToCart: _handleAddToCart,
            onPay: _handlePay,
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HomeHeader (Section 3A)
  // ─────────────────────────────────────────────
  Widget _buildHeader(dynamic user) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(21, 8, 21, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Hi ${user?.name ?? 'User'}!',
            style: GoogleFonts.poppins(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/notifications'),
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.profileAvatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HomeHeader + BalanceCard wrapper — the balance card overlaps
  // the header by 56px (top:86 vs header height:142), matching the
  // React reference (Home.tsx `<BalanceCard />` positioned `top-[86px]`
  // inside the header's `relative` wrapper).
  // ─────────────────────────────────────────────
  Widget _buildHeaderSection(dynamic user, AsyncValue walletAsync, double screenWidth) {
    return SizedBox(
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildHeader(user),
          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: _buildBalanceCard(walletAsync, screenWidth),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BalanceCard (Section 3B) — 3-layer glassmorphism
  // ─────────────────────────────────────────────
  Widget _buildBalanceCard(AsyncValue walletAsync, double screenWidth) {
    final cardWidth = (screenWidth * 0.90).clamp(0.0, 350.0);
    final cardWidthInner = cardWidth - 32;
    final cardWidthBack = cardWidth - 56;

    return SizedBox(
      height: 156,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Layer 1 — furthest back (shadow-lg + backdrop-blur-sm)
          Positioned(
            top: 40,
            child: Container(
              width: cardWidthBack,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, spreadRadius: -3, offset: const Offset(0, 10)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, spreadRadius: -4, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Layer 2 — middle (shadow-xl + backdrop-blur-sm)
          Positioned(
            top: 24,
            child: Container(
              width: cardWidthInner,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 25, spreadRadius: -5, offset: const Offset(0, 20)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: -6, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Layer 3 — front with float animation (shadow + backdrop-blur-md)
          Positioned(
            top: 0,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: child,
              ),
              child: Container(
                width: cardWidth,
                height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.balanceCardShadow,
                      blurRadius: 38,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Stack(
                      children: [
                        // Decorative watermark gift icons
                        Positioned(
                          left: 148,
                          top: 12,
                          child: Transform.rotate(
                            angle: -18 * 3.14159265 / 180,
                            child: Opacity(
                              opacity: 0.16,
                              child: Image.asset(
                                'assets/images/Gift.png',
                                width: 42,
                                height: 42,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 82,
                          top: 63,
                          child: Transform.rotate(
                            angle: -21 * 3.14159265 / 180,
                            child: Opacity(
                              opacity: 0.16,
                              child: Image.asset(
                                'assets/images/Gift.png',
                                width: 42,
                                height: 42,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 25,
                          top: 62,
                          child: Transform.rotate(
                            angle: -20 * 3.14159265 / 180,
                            child: Opacity(
                              opacity: 0.16,
                              child: Image.asset(
                                'assets/images/Gift.png',
                                width: 34,
                                height: 34,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -9,
                          bottom: 9,
                          child: Transform.rotate(
                            angle: -17 * 3.14159265 / 180,
                            child: Opacity(
                              opacity: 0.16,
                              child: Icon(
                                Icons.wallet_giftcard,
                                size: 34,
                                color: AppColors.giftWatermark,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 30,
                          top: 15,
                          child: Transform.rotate(
                            angle: -14 * 3.14159265 / 180,
                            child: Opacity(
                              opacity: 0.16,
                              child: Icon(
                                Icons.wallet_giftcard,
                                size: 37,
                                color: AppColors.giftWatermark,
                              ),
                            ),
                          ),
                        ),

                        // Main balance content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gift360 Balance',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Text(
                                  _balanceVisible
                                      ? '₹ ${_formatBalance(walletAsync.valueOrNull?.totalBalance ?? 0)}'
                                      : '₹ •••••••',
                                  style: GoogleFonts.poppins(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                GestureDetector(
                                  onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                                  child: Icon(
                                    _balanceVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 19,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Flipkart SuperCoin CTA — white logo card + gold frame + caption
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _SuperCoinCtaWidget(),
                        ),
                      ],
                    ),
                  ),
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
  // ActionGrid (Section 3C)
  // ─────────────────────────────────────────────
  Widget _buildActionGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(31, 26, 31, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionItem(
            icon: Icons.card_giftcard_rounded,
            label: 'Buy Voucher',
            onTap: () => _showCategoriesBottomSheet(),
          ),
          _buildActionItem(
            icon: Icons.send_outlined,
            label: 'Near by stores',
            onTap: () => context.push('/nearby'),
          ),
          _buildActionItem(
            icon: Icons.shopping_bag_outlined,
            label: 'Orders',
            onTap: () => context.push('/orders'),
          ),
          _buildActionItem(
            icon: Icons.person_add_outlined,
            label: 'Partner with Us',
            onTap: () => context.push('/distributor'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: AppColors.actionIconBg,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30151C4A),
                  blurRadius: 7,
                  offset: Offset(4, 5),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 27,
              color: AppColors.actionIconColor,
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 65,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SearchSection (Section 3D)
  // ─────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Column(
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.searchBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    setState(() => _showSuggestions = value.trim().isNotEmpty);
                  },
                  onTap: () {
                    if (_searchController.text.trim().isNotEmpty) {
                      setState(() => _showSuggestions = true);
                    }
                  },
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      context.push('/brands?search=${Uri.encodeComponent(value.trim())}');
                      setState(() => _showSuggestions = false);
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search brands, vouchers...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        if (_showSuggestions) _buildSearchSuggestions(),
      ],
    );
  }

  Widget _buildSearchSuggestions() {
    final brandNamesAsync = ref.watch(brandNamesProvider);
    return brandNamesAsync.when(
      data: (brandNames) {
        final query = _searchController.text.trim().toLowerCase();
        if (query.isEmpty) return const SizedBox.shrink();
        final filtered = brandNames
            .where((b) => b.brandName.toLowerCase().contains(query))
            .take(8)
            .toList();
        if (filtered.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.searchBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: filtered.map((brand) => _buildSuggestionItem(brand)).toList(),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, e) => const SizedBox.shrink(),
    );
  }

  Widget _buildSuggestionItem(BrandName brand) {
    return InkWell(
      onTap: () {
        _openPaymentSheet(brand.brandId);
        setState(() => _showSuggestions = false);
        _searchController.clear();
        _searchFocusNode.unfocus();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              brand.brandName,
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
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Categories Bottom Sheet
  // ─────────────────────────────────────────────
  void _showCategoriesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final filterMetaAsync = ref.watch(filterMetaProvider);
          final brandsAsync = ref.watch(brandsProvider);

          return filterMetaAsync.when(
            data: (meta) {
              final categoryList = meta.categories;

              return brandsAsync.when(
                data: (brands) {
                  final brandCounts = <String, int>{};
                  for (final brand in brands) {
                    final category = brand.category?.trim();
                    if (category != null && category.isNotEmpty) {
                      brandCounts[category] = (brandCounts[category] ?? 0) + 1;
                    }
                  }

                  final categories = <String, int>{
                    for (final category in categoryList) category: brandCounts[category] ?? 0,
                  };

                  return DraggableScrollableSheet(
                    initialChildSize: 0.88,
                    minChildSize: 0.3,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) => Container(
                      decoration: const BoxDecoration(
                        color: AppColors.sheetBg,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC6CAD6),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Categories',
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _buildFilterChip('Super Cashbacks', true),
                                const SizedBox(width: 8),
                                _buildFilterChip("Today's Pick", false),
                                const SizedBox(width: 8),
                                _buildFilterChip('Under ?50', false),
                                const SizedBox(width: 8),
                                _buildFilterChip('Filter', false, isFilter: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: categoryList.isEmpty
                                ? _buildLoadingCategories(context, scrollController)
                                : GridView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 2.8,
                                    ),
                                    itemCount: categoryList.length,
                                    itemBuilder: (context, index) {
                                      final category = categoryList[index];
                                      final count = categories[category] ?? 0;
                                      return _buildCategoryCard(category, count, context);
                                    },
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDEAFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${brands.length} brands',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6C5CE7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(brandsProvider),
                    child: const Text('Retry'),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(filterMetaProvider),
                child: const Text('Retry'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, {bool isFilter = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEDEAFF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFilter
              ? AppColors.categoryFilterBg
              : (isActive ? AppColors.categoryFilterBg : AppColors.divider),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFilter) ...[
            const Icon(Icons.tune, size: 14, color: AppColors.categoryFilterBg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isFilter
                  ? AppColors.categoryFilterBg
                  : (isActive ? AppColors.categoryFilterBg : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, int count, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.push('/brands?categories=${Uri.encodeComponent(category)}');
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A1F213B),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF20222C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$count brands',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF7A7F8F),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF7A7F8F)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCategories(BuildContext context, ScrollController scrollController) {
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 50,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Payment / voucher logic (UNCHANGED)
  // ─────────────────────────────────────────────
  void _openPaymentSheet(String brandId) {
    if (brandId.isEmpty) return;
    setState(() {
      _showPaymentSheet = true;
      _paymentBrand = null;
      _paymentLoading = true;
      _paymentError = null;
    });
    _fetchPaymentDetails(brandId);
  }

  void _openTopBrandModal(String brandId) {
    if (brandId.isEmpty) return;
    setState(() {
      _selectedBrand = null;
      _showVoucherModal = true;
      _voucherLoading = true;
      _voucherError = null;
      _vouchers = [];
    });
    _fetchVouchers(brandId);
  }

  Future<void> _fetchVouchers(String brandId) async {
    try {
      final api = ref.read(brandsApiProvider);
      final details = await api.getBrandVoucherList(brandId);
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
        if (enriched.isNotEmpty && _selectedBrand == null) {
          _selectedBrand = enriched.first;
        }
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

  void _fetchPaymentDetailsForVoucher(Brand voucher) {
    _fetchPaymentDetails(voucher.brandId ?? '');
  }

  Future<void> _fetchPaymentDetails(String brandId) async {
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

  void _handleAddToCart(Brand brand, double amount, int quantity) {
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

  String _formatBalance(double amount) {
    return amount.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════
// SuperCoin CTA — white logo card with gold frame, glow pulse, and caption.
// ═══════════════════════════════════════════════
class _SuperCoinCtaWidget extends StatefulWidget {
  const _SuperCoinCtaWidget();

  @override
  State<_SuperCoinCtaWidget> createState() => _SuperCoinCtaWidgetState();
}

class _SuperCoinCtaWidgetState extends State<_SuperCoinCtaWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAlpha;
  late final Animation<double> _borderAlpha;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    final curve = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _glowAlpha = Tween<double>(begin: 0.25, end: 0.5).animate(curve);
    _borderAlpha = Tween<double>(begin: 0.4, end: 0.7).animate(curve);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        // TODO: wire to SuperCoin conversion flow
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: _borderAlpha.value),
                      width: 1.5,
                    ),
                    boxShadow: [
                      // Gold glow
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: _glowAlpha.value),
                        blurRadius: 20,
                        offset: Offset.zero,
                      ),
                      // Dark elevation
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/FlipKartSuperCoin-removebg-preview.png',
                    height: 50,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Earn SuperCoins',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                ),
                const SizedBox(width: 1),
                Icon(
                  Icons.chevron_right,
                  size: 12,
                  color: AppColors.goldLight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// RecommendedList (Section 3F)
// ═══════════════════════════════════════════════
class _RecommendedSection extends ConsumerWidget {
  final void Function(String brandId) onBuy;

  const _RecommendedSection({required this.onBuy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(allBrandsProvider);
    return brandsAsync.when(
      data: (brands) {
        final recommended = brands
            .where((b) {
              final d = double.tryParse(b.discount ?? '0');
              return d != null && d > 0;
            })
            .toList()
          ..sort((a, b) => double.parse(b.discount ?? '0').compareTo(double.parse(a.discount ?? '0')));
        final items = recommended.take(6).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 27, 21, 0),
              child: Text(
                'Recommended',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(21, 0, 21, 3),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, i) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final brand = items[index];
                  return _buildRecommendedCard(context, brand);
                },
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(21, 27, 21, 0),
        child: SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, __) => _RecommendedShimmerCard(),
          ),
        ),
      ),
      error: (_, e) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecommendedCard(BuildContext context, Brand brand) {
    final price = brand.effectiveStartingPrice;
    final imageUrl = brand.resolvedImageUrl ?? 'https://images.gift360.io/${brand.brandId}.png';
    return GestureDetector(
      onTap: () => onBuy(brand.brandId ?? ''),
      child: Container(
        width: 120,
        height: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: BrandImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand.brandName ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
            const SizedBox(height: 3),
                        Text(
                          price > 0 ? '₹${price.toInt()} Voucher' : 'Voucher',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  price > 0 ? '₹${price.toInt()}' : '-',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.buyButtonGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Buy',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 40,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 40,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// TopBrandsGrid (Section 3G) — Marquee
// ═══════════════════════════════════════════════
class _TopBrandsSection extends ConsumerStatefulWidget {
  final void Function(String brandId) onBrandTap;

  const _TopBrandsSection({required this.onBrandTap});
  @override
  ConsumerState<_TopBrandsSection> createState() => _TopBrandsSectionState();
}

class _TopBrandsSectionState extends ConsumerState<_TopBrandsSection>
    with TickerProviderStateMixin {
  AnimationController? _row1Controller;
  AnimationController? _row2Controller;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _row1Controller?.dispose();
    _row2Controller?.dispose();
    super.dispose();
  }

  void _initAnimations() {
    if (_row1Controller != null) return;
    _row1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 200),
    )..repeat();
    _row2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 220),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final topBrandsAsync = ref.watch(topBrandsProvider);
    return topBrandsAsync.when(
      data: (brands) {
        if (brands.isEmpty) return const SizedBox.shrink();
        _initAnimations();

        final indexed = brands.asMap();
        final firstRow = indexed.entries.where((e) => e.key.isEven).map((e) => e.value).toList();
        final secondRow = indexed.entries.where((e) => e.key.isOdd).map((e) => e.value).toList();
        if (secondRow.isEmpty) return const SizedBox.shrink();

        const cardWidth = 88.0;
        const gapWidth = 12.0;
        const itemWidth = cardWidth + gapWidth;
        final firstHalfWidth = firstRow.length * itemWidth;
        final secondHalfWidth = secondRow.length * itemWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 26, 21, 0),
              child: Text(
                'Top Brands',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 204,
              child: Column(
                children: [
                  _buildMarqueeRow(
                    controller: _row1Controller!,
                    items: firstRow,
                    duplicatedItems: [...firstRow, ...firstRow],
                    halfWidth: firstHalfWidth,
                    isLTR: true,
                  ),
                  const SizedBox(height: 12),
                  _buildMarqueeRow(
                    controller: _row2Controller!,
                    items: secondRow,
                    duplicatedItems: [...secondRow, ...secondRow],
                    halfWidth: secondHalfWidth,
                    isLTR: false,
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(21, 26, 21, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 19),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, __) => _TopBrandShimmerCard(),
              ),
            ),
          ],
        ),
      ),
      error: (_, e) => Padding(
        padding: const EdgeInsets.fromLTRB(21, 26, 21, 0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Failed to load brands',
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF991B1B)),
              ),
            ),
            GestureDetector(
              onTap: () => ref.invalidate(topBrandsProvider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarqueeRow({
    required AnimationController controller,
    required List<Brand> items,
    required List<Brand> duplicatedItems,
    required double halfWidth,
    required bool isLTR,
  }) {
    return Listener(
      onPointerDown: (_) => controller.stop(),
      onPointerUp: (_) => controller.repeat(),
      onPointerCancel: (_) => controller.repeat(),
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
              AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final offset = isLTR
                      ? controller.drive(Tween(begin: -halfWidth, end: 0.0))
                      : controller.drive(Tween(begin: 0.0, end: -halfWidth));
                  return Transform.translate(
                    offset: Offset(offset.value, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: duplicatedItems
                      .map((brand) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildTopBrandCard(brand),
                          ))
                      .toList(),
                ),
              ),
              // Left fade
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.scaffoldBg.withValues(alpha: 0.95),
                          AppColors.scaffoldBg.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
              // Right fade
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.scaffoldBg.withValues(alpha: 0.0),
                          AppColors.scaffoldBg.withValues(alpha: 0.95),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildTopBrandCard(Brand brand) {
    final discount = brand.discount ?? '';
    final meta = discount.isNotEmpty ? '$discount% Cashback' : (brand.category ?? 'Gift Voucher');
    final imageUrl = brand.resolvedImageUrl;
    return GestureDetector(
      onTap: () => widget.onBrandTap(brand.brandId ?? ''),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 88,
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: imageUrl != null
                  ? BrandImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => const Icon(Icons.store, color: Color(0xFF94A3B8)),
                    )
                  : const Icon(Icons.store, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 8),
            Text(
              brand.brandName ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.brandCardText,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppColors.brandCardMeta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBrandShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 50,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// RecentlyUsed (Section 3H)
// ═══════════════════════════════════════════════
class _RecentlyUsedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyUsedAsync = ref.watch(recentlyUsedProvider);
    return recentlyUsedAsync.when(
      data: (items) {
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        final displayItems = items.take(6).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(21, 27, 21, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recently Used',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: displayItems
                    .map((item) => _buildRecentlyUsedItem(context, item))
                    .toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 30),
      error: (_, e) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentlyUsedItem(BuildContext context, RecentlyUsedBrand item) {
    final imageUrl = item.imageUrl ?? (item.brandId.isNotEmpty ? 'https://images.gift360.io/${item.brandId}.png' : null);
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x381A1E31),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: imageUrl != null
              ? ClipOval(
                  child: SizedBox(
                    width: 35,
                    height: 35,
                    child: BrandImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Icon(Icons.store, size: 18, color: Color(0xFF94A3B8)),
                      errorWidget: (_, __, ___) => const Icon(Icons.store, size: 18, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              : const Icon(Icons.store, size: 18, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}
