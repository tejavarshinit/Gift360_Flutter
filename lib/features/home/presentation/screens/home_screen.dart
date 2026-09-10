import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/brands/presentation/providers/brand_names_provider.dart';
import 'package:gift360/features/brands/presentation/providers/top_brands_provider.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/data/models/brand_name.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/home/presentation/widgets/instant_gifting_carousel.dart';
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
import 'package:gift360/features/home/presentation/providers/home_providers.dart';
import 'package:gift360/features/support/presentation/widgets/support_chat_widget.dart';
import 'package:gift360/features/supercoin/presentation/widgets/supercoin_buy_sheet.dart';
import 'package:gift360/features/supercoin/data/supercoin_excluded_brands.dart';
import 'package:gift360/features/feedback/presentation/providers/feedback_provider.dart';
import 'package:gift360/features/feedback/presentation/widgets/feedback_form.dart';
import 'package:gift360/core/widgets/react_backdrop.dart';
import 'package:gift360/core/widgets/gift_header.dart';

class _FeedbackToast extends StatelessWidget {
  const _FeedbackToast();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "We'd love your feedback!",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Tap the feedback icon up top to share your thoughts.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
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
  String _displayName = '';

  bool _showVoucherModal = false;
  bool _voucherLoading = false;
  String? _voucherError;
  Brand? _selectedBrand;
  List<Brand> _vouchers = [];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(
      begin: 0,
      end: -10,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_floatController);
    // Feedback prompt: show toast after 15s for logged-in users who haven't submitted/been prompted
    _scheduleFeedbackPrompt();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('displayName') ?? '';
      if (mounted && saved.trim().isNotEmpty) {
        setState(() => _displayName = saved.trim());
      }
    } catch (_) {}
  }

  /// Greeting name — matches React: `displayName || user?.name || "User"`,
  /// then takes only the first word.
  String _greetingName(dynamic user) {
    final raw =
        (_displayName.isNotEmpty ? _displayName : user?.name?.toString() ?? '')
            .trim();
    if (raw.isEmpty) return 'User';
    final first = raw.split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'User' : first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _floatController.dispose();
    _feedbackPromptTimer?.cancel();
    _feedbackToastTimer?.cancel();
    super.dispose();
  }

  Timer? _feedbackPromptTimer;
  Timer? _feedbackToastTimer;
  bool _showFeedbackToast = false;

  void _scheduleFeedbackPrompt() {
    _feedbackPromptTimer = Timer(const Duration(seconds: 15), () async {
      if (!mounted) return;
      final user = ref.read(authProvider);
      if (user == null) return; // skip guests
      final hasSubmitted = await FeedbackNotifier.hasSubmittedFeedback();
      final hasBeenPrompted = await FeedbackNotifier.hasBeenPrompted();
      if (hasSubmitted || hasBeenPrompted) return;
      // Mark as prompted so it won't nag again
      await FeedbackNotifier.markPrompted();
      if (!mounted) return;
      setState(() => _showFeedbackToast = true);
      _feedbackToastTimer?.cancel();
      _feedbackToastTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showFeedbackToast = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final walletAsync = ref.watch(walletBalanceProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        const Positioned.fill(child: ReactBackdrop(child: SizedBox.shrink())),
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

                // ── Instant Gifting Carousel ──
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 21),
                  child: InstantGiftingCarousel(
                    onExploreBrands: () => context.push('/brands'),
                    onPartnerWithUs: () => context.push('/distributor'),
                    onBrandTap: _openInstantGiftingBrand,
                  ),
                ),

                _buildRakhiPromoBanner(),

                // ── Personal Picks (AI recommendations) ──
                _PersonalPicksSection(onBuy: _openPaymentSheet),

                // ── RecommendedList ──
                // ── Occasion-based sections ──
                _OccasionSections(onBuy: _openTopBrandModal),

                // ── TopBrandsGrid ──
                _TopBrandsSection(onBrandTap: _openTopBrandModal),

                // ── RecentlyUsed ──
                _RecentlyUsedSection(onBuy: _openPaymentSheet),

                // ── Social Media Links ──
                _buildSocialMediaLinks(),

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
        if (_showFeedbackToast)
          const Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _FeedbackToast(),
          ),
        // ── Support Chat Widget (floating) ──
        const Positioned(bottom: 72, right: 16, child: SupportChatWidget()),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HomeHeader (Section 3A)
  // ─────────────────────────────────────────────
  Widget _buildHeader(dynamic user) {
    return Container(
      height: 142,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(21, 40, 21, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi ${_greetingName(user)}!',
            style: GoogleFonts.poppins(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              SuperCoinHeaderIcon(onTap: () => openSuperCoinBuySheet(context)),
              const SizedBox(width: 14),
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
                    child: Icon(Icons.person, size: 14, color: Colors.white),
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
  Widget _buildHeaderSection(
    dynamic user,
    AsyncValue walletAsync,
    double screenWidth,
  ) {
    return SizedBox(
      height: 212,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildHeader(user),
          Positioned(
            top: 86,
            left: 0,
            right: 0,
            child: Center(
              child: _buildReferenceBalanceCard(walletAsync, screenWidth),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BalanceCard (Section 3B) — 3-layer glassmorphism
  // ─────────────────────────────────────────────
  Widget _buildReferenceBalanceCard(
    AsyncValue walletAsync,
    double screenWidth,
  ) {
    final cardWidth = (screenWidth - 64).clamp(0.0, 350.0).toDouble();
    final balance = walletAsync.valueOrNull?.totalBalance ?? 0;

    return SizedBox(
      width: cardWidth,
      height: 156,
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/ganeshwalletpoints.png',
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 10, 6),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your CashBack points',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                _balanceVisible
                                    ? '₹ ${balance.toStringAsFixed(2)}'
                                    : '₹ •••••••',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _balanceVisible = !_balanceVisible,
                                ),
                                child: Icon(
                                  _balanceVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 19,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/SuperCOin-removebg-preview.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'SuperCoins now available on',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Image.asset(
                                'assets/images/G word.png',
                                height: 12,
                                fit: BoxFit.contain,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildRakhiPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 12,
                  offset: Offset(4, 4),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/ganeshbannercard.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

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
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: -3,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    spreadRadius: -4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
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
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 25,
                    spreadRadius: -5,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
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
                                    onTap: () => setState(
                                      () => _balanceVisible = !_balanceVisible,
                                    ),
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
      padding: const EdgeInsets.fromLTRB(21, 26, 21, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionItem(
              icon: Icons.redeem,
              label: 'Buy Voucher',
              onTap: _showCategoriesBottomSheet,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: _buildActionItem(
              icon: Icons.send,
              label: 'Offers Near You',
              onTap: () => context.push('/nearby'),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: _buildActionItem(
              icon: Icons.inventory_2,
              label: 'Orders',
              onTap: () => context.push('/orders'),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: _buildActionItem(
              icon: Icons.person_add_alt_1,
              label: 'Partner with Us',
              onTap: () => context.push('/distributor'),
            ),
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
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                  child: Icon(icon, size: 27, color: AppColors.actionIconColor),
                ),
                if (label == 'Offers Near You')
                  Positioned(top: -9, left: 12, child: _buildTryNowBadge()),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 18,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF161616),
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTryNowBadge() {
    return const _AnimatedTryNowBadge();
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
              const Icon(
                Icons.search,
                size: 16,
                color: AppColors.textSecondary,
              ),
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
                      context.push(
                        '/brands?search=${Uri.encodeComponent(value.trim())}',
                      );
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
            children: filtered
                .map((brand) => _buildSuggestionItem(brand))
                .toList(),
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
                    for (final category in categoryList)
                      category: brandCounts[category] ?? 0,
                  };

                  return DraggableScrollableSheet(
                    initialChildSize: 0.88,
                    minChildSize: 0.3,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) => Container(
                      decoration: const BoxDecoration(
                        color: AppColors.sheetBg,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
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
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              children: [
                                _buildFilterChip('Super Cashbacks', true),
                                const SizedBox(width: 8),
                                _buildFilterChip("Today's Pick", false),
                                const SizedBox(width: 8),
                                _buildFilterChip('Under ?50', false),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  'Filter',
                                  false,
                                  isFilter: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: categoryList.isEmpty
                                ? _buildLoadingCategories(
                                    context,
                                    scrollController,
                                  )
                                : GridView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      16,
                                    ),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 2.8,
                                        ),
                                    itemCount: categoryList.length,
                                    itemBuilder: (context, index) {
                                      final category = categoryList[index];
                                      final count = categories[category] ?? 0;
                                      return _buildCategoryCard(
                                        category,
                                        count,
                                        context,
                                      );
                                    },
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
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

  Widget _buildFilterChip(
    String label,
    bool isActive, {
    bool isFilter = false,
  }) {
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
                  : (isActive
                        ? AppColors.categoryFilterBg
                        : AppColors.textSecondary),
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

  Widget _buildLoadingCategories(
    BuildContext context,
    ScrollController scrollController,
  ) {
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

  /// Open the payment sheet for an instant-gifting brand. The carousel now
  /// passes hardcoded brand UUIDs (matches React InstantGiftingBanner), so no
  /// name lookup is required.
  void _openInstantGiftingBrand(String brandId) {
    if (brandId.isEmpty) return;
    _openPaymentSheet(brandId);
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
        final needsDetails =
            (voucher.minPrice == null || voucher.minPrice == 0) &&
            (voucher.maxPrice == null || voucher.maxPrice == 0) &&
            (voucher.denominationList == null ||
                voucher.denominationList!.isEmpty);
        if (needsDetails &&
            voucher.brandId != null &&
            voucher.brandId!.isNotEmpty) {
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
    ref
        .read(cartProvider.notifier)
        .addToCart(
          AddToCartRequest(
            brandId: brand.brandId ?? '',
            brandName: brand.brandName ?? '',
            quantity: quantity,
            unitValue: amount,
            image: brand.resolvedImageUrl,
          ),
        );
    ref
        .read(notificationProvider.notifier)
        .addNotification(
          title: 'Added to Cart',
          message:
              '${brand.brandName} voucher has been added successfully into cart',
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
      SnackBar(
        content: Text(
          '${quantity}x ${brand.brandName} voucher(s) of ₹${amount.toInt()} added to cart',
        ),
      ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Brand ID not available')));
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
      if (!mounted) return;
      if (orderNumber == null) {
        final err = ref.read(paymentProvider).error ?? 'Failed to create order';
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      final valid = await paymentNotifier.validateOrder(
        cartTotal: totalAmount,
        walletAmount: 0,
        walletUsed: false,
      );
      if (!mounted) return;
      if (!valid) {
        final err =
            ref.read(paymentProvider).error ?? 'Order validation failed';
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      // Backend-mediated payment initiation (backend computes net payable).
      final paymentResponse = await paymentNotifier.initiateBackendPayment();
      if (!mounted) return;
      if (paymentResponse == null) {
        final err =
            ref.read(paymentProvider).error ?? 'Payment initiation failed';
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      final paymentUrl =
          paymentResponse['payment_url'] ?? paymentResponse['paymentUrl'];
      if (paymentUrl == null || paymentUrl.toString().isEmpty) {
        setState(() => _paymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment URL not received from gateway'),
          ),
        );
        return;
      }

      setState(() {
        _paymentProcessing = false;
        _showPaymentSheet = false;
        _paymentBrand = null;
      });

      context.push(
        '/payment-webview',
        extra: {
          'paymentUrl': paymentUrl.toString(),
          'orderNumber': orderNumber,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment error: ${e.toString()}')));
    }
  }

  String _formatBalance(double amount) {
    // Matches React's `toLocaleString("en-IN")` grouping (e.g. 12,345.67).
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: 2,
    ).format(amount);
  }

  // Certification logo + social handles — matches React Home.tsx
  // (cert logo section px-21 pt-27 pb-10 h-10, then social section px-21 pt-6 pb-14).
  Widget _buildSocialMediaLinks() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 27, 21, 10),
          child: Center(
            child: Image.asset(
              'assets/images/certf logo.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 6, 21, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _SocialIconButton(
                svg: _instagramSvg,
                url: 'https://www.instagram.com/gift360.io/',
                label: 'Instagram',
              ),
              SizedBox(width: 20),
              _SocialIconButton(
                svg: _facebookSvg,
                url: 'https://www.facebook.com/profile.php?id=61593994256161',
                label: 'Facebook',
              ),
              SizedBox(width: 20),
              _SocialIconButton(
                svg: _youtubeSvg,
                url: 'https://www.youtube.com/@Gift360-io',
                label: 'YouTube',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Brand SVG glyphs — same paths/colors as the lucide-react icons used in
// React's Home.tsx social section (Instagram #E1306C, Facebook #1877F2, YouTube #FF0000).
const String _instagramSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#E1306C" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    '<rect width="20" height="20" x="2" y="2" rx="5" ry="5"></rect>'
    '<path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"></path>'
    '<line x1="17.5" x2="17.51" y1="6.5" y2="6.5"></line></svg>';

const String _facebookSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#1877F2" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"></path></svg>';

const String _youtubeSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#FF0000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M2.5 17a24.12 24.12 0 0 1 0-10 2 2 0 0 1 1.4-1.4 49.56 49.56 0 0 1 16.2 0A2 2 0 0 1 21.5 7a24.12 24.12 0 0 1 0 10 2 2 0 0 1-1.4 1.4 49.55 49.55 0 0 1-16.2 0A2 2 0 0 1 2.5 17"></path>'
    '<path d="m10 15 5-3-5-3z"></path></svg>';

// Pressable social handle circle — 36px, white, #EDEDED border, Tailwind shadow-sm,
// active:scale-95, launches in external browser. Mirrors React anchor styling.
class _SocialIconButton extends StatefulWidget {
  final String svg;
  final String url;
  final String label;

  const _SocialIconButton({
    required this.svg,
    required this.url,
    required this.label,
  });

  @override
  State<_SocialIconButton> createState() => _SocialIconButtonState();
}

class _SocialIconButtonState extends State<_SocialIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () async {
          final uri = Uri.parse(widget.url);
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            // Best effort — ignore launch failures.
          }
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEDEDED)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: SvgPicture.string(
              widget.svg,
              width: 18,
              height: 18,
              placeholderBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SuperCoin CTA — white logo card with gold frame, glow pulse, and caption.
// ═══════════════════════════════════════════════
class _AnimatedTryNowBadge extends StatefulWidget {
  const _AnimatedTryNowBadge();

  @override
  State<_AnimatedTryNowBadge> createState() => _AnimatedTryNowBadgeState();
}

class _AnimatedTryNowBadgeState extends State<_AnimatedTryNowBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 1 + math.sin(_controller.value * math.pi * 2) * 0.04;
        final glow = 4 + (math.sin(_controller.value * math.pi * 2) + 1) * 5;
        final shimmerLeft = -22 + (_controller.value * 66);
        final gradientPosition = -1 + (_controller.value * 2);

        return Transform.scale(
          scale: pulse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(gradientPosition, 0),
                end: Alignment(gradientPosition + 2, 0),
                colors: const [
                  Color(0xFF7C3AED),
                  Color(0xFFEC4899),
                  Color(0xFF3B82F6),
                  Color(0xFF7C3AED),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.38),
                  blurRadius: glow,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  Text(
                    'Try Now',
                    style: GoogleFonts.poppins(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Positioned(
                    left: shimmerLeft,
                    top: -5,
                    bottom: -5,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.skewX(-0.25),
                      child: Container(
                        width: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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

    final curve = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
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
        openSuperCoinBuySheet(context);
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
                      color: AppColors.gold.withValues(
                        alpha: _borderAlpha.value,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: [
                      // Gold glow
                      BoxShadow(
                        color: AppColors.gold.withValues(
                          alpha: _glowAlpha.value,
                        ),
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
                Icon(Icons.chevron_right, size: 12, color: AppColors.goldLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Personal Picks (AI-powered recommendations)
// ═══════════════════════════════════════════════
class _PersonalPicksSection extends ConsumerWidget {
  final void Function(String brandId) onBuy;

  const _PersonalPicksSection({required this.onBuy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picksAsync = ref.watch(personalRecommendationsProvider);

    return picksAsync.when(
      data: (brands) {
        if (brands.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 24, 21, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Picks for You',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/brands'),
                    child: Text(
                      'See All',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 21),
                itemCount: brands.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final brand = brands[index];
                  return GestureDetector(
                    onTap: () => onBuy(brand.brandId ?? ''),
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (brand.resolvedImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BrandImage(
                                imageUrl: brand.resolvedImageUrl!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.store,
                                size: 32,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              brand.brandName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════
// Occasion-based Sections
// ═══════════════════════════════════════════════
class _OccasionSections extends ConsumerWidget {
  final void Function(String brandId) onBuy;

  const _OccasionSections({required this.onBuy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occasionsAsync = ref.watch(occasionsProvider);

    return occasionsAsync.when(
      data: (occasions) {
        if (occasions.isEmpty) return const SizedBox.shrink();
        // Filter out "Top Brands" because TopBrandsSection has its own
        // dedicated component with a marquee layout (matches React behavior).
        final filteredOccasions = occasions
            .where((o) => o.trim().toLowerCase() != 'top brands')
            .toList();
        if (filteredOccasions.isEmpty) return const SizedBox.shrink();
        return Column(
          children: filteredOccasions.map((occasion) {
            return _OccasionSection(occasion: occasion, onBuy: onBuy);
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _OccasionSection extends ConsumerWidget {
  final String occasion;
  final void Function(String brandId) onBuy;

  const _OccasionSection({required this.occasion, required this.onBuy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(occasionRecommendationsProvider(occasion));

    return brandsAsync.when(
      data: (brands) {
        if (brands.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 26, 21, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  occasion,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 107,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(21, 11, 21, 0),
                itemCount: brands.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final brand = brands[index];
                  return GestureDetector(
                    onTap: () => onBuy(brand.brandId ?? ''),
                    child: Container(
                      width: 88,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (brand.resolvedImageUrl != null)
                                Center(
                                  child: SizedBox(
                                    width: 60,
                                    height: 42,
                                    child: BrandImage(
                                      imageUrl: brand.resolvedImageUrl!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )
                              else
                                const Center(
                                  child: SizedBox(
                                    width: 60,
                                    height: 42,
                                    child: Icon(
                                      Icons.store,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  brand.brandName ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((double.tryParse(brand.discount ?? '0') ?? 0) > 0)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C5CE7),
                                      Color(0xFF5A4BD1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${double.tryParse(brand.discount ?? '0')!.toStringAsFixed(0)}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (isSuperCoinEligible(
                            brandId: brand.brandId,
                            brandName: brand.brandName,
                          ))
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Image.asset(
                                'assets/images/SuperCOin-removebg-preview.png',
                                width: 16,
                                height: 16,
                                fit: BoxFit.contain,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
        final recommended =
            brands.where((b) {
              final d = double.tryParse(b.discount ?? '0');
              return d != null && d > 0;
            }).toList()..sort(
              (a, b) => double.parse(
                b.discount ?? '0',
              ).compareTo(double.parse(a.discount ?? '0')),
            );
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
    final imageUrl =
        brand.resolvedImageUrl ??
        'https://images.gift360.io/${brand.brandId}.png';
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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

class _TopBrandsSectionState extends ConsumerState<_TopBrandsSection> {
  final ScrollController _row1Scroll = ScrollController();
  final ScrollController _row2Scroll = ScrollController();
  bool _userTouching = false;
  Timer? _autoScrollTimer1;
  Timer? _autoScrollTimer2;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _row1Scroll.dispose();
    _row2Scroll.dispose();
    _autoScrollTimer1?.cancel();
    _autoScrollTimer2?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer1 = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_userTouching || !_row1Scroll.hasClients) return;
      final maxScroll = _row1Scroll.position.maxScrollExtent;
      final current = _row1Scroll.offset;
      if (current >= maxScroll) {
        _row1Scroll.jumpTo(0);
      } else {
        _row1Scroll.jumpTo(current + 0.5);
      }
    });
    _autoScrollTimer2 = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_userTouching || !_row2Scroll.hasClients) return;
      final maxScroll = _row2Scroll.position.maxScrollExtent;
      final current = _row2Scroll.offset;
      if (current >= maxScroll) {
        _row2Scroll.jumpTo(0);
      } else {
        _row2Scroll.jumpTo(current + 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topBrandsAsync = ref.watch(topBrandsProvider);
    return topBrandsAsync.when(
      data: (brands) {
        if (brands.isEmpty) return const SizedBox.shrink();

        final indexed = brands.asMap();
        final firstRow = indexed.entries
            .where((e) => e.key.isEven)
            .map((e) => e.value)
            .toList();
        final secondRow = indexed.entries
            .where((e) => e.key.isOdd)
            .map((e) => e.value)
            .toList();
        if (secondRow.isEmpty) return const SizedBox.shrink();

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
            _buildAutoScrollRow(firstRow, _row1Scroll),
            const SizedBox(height: 12),
            _buildAutoScrollRow(secondRow, _row2Scroll),
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
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => ref.invalidate(topBrandsProvider),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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

  Widget _buildAutoScrollRow(
    List<Brand> rowBrands,
    ScrollController controller,
  ) {
    return Listener(
      onPointerDown: (_) {
        _userTouching = true;
      },
      onPointerUp: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _userTouching = false;
        });
      },
      onPointerCancel: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _userTouching = false;
        });
      },
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 21),
          itemCount: rowBrands.length * 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, index) {
            final brand = rowBrands[index % rowBrands.length];
            return _buildTopBrandCard(brand);
          },
        ),
      ),
    );
  }

  Widget _buildTopBrandCard(Brand brand) {
    final discount = brand.discount ?? '';
    final discountValue = double.tryParse(discount) ?? 0;
    final meta = discount.isNotEmpty
        ? '$discount% Cashback'
        : (brand.category ?? 'Gift Voucher');
    final imageUrl = brand.resolvedImageUrl;
    return GestureDetector(
      onTap: () => widget.onBrandTap(brand.brandId ?? ''),
      behavior: HitTestBehavior.deferToChild,
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
        child: Stack(
          children: [
            Column(
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
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.store, color: Color(0xFF94A3B8)),
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
            if (discountValue > 0)
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF5A4BD1)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0x447C3AED), blurRadius: 5),
                    ],
                  ),
                  child: Text(
                    '${discountValue.toStringAsFixed(discountValue == discountValue.roundToDouble() ? 0 : 1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (isSuperCoinEligible(
              brandId: brand.brandId,
              brandName: brand.brandName,
            ))
              Positioned(
                top: 5,
                right: 5,
                child: Image.asset(
                  'assets/images/SuperCOin-removebg-preview.png',
                  width: 16,
                  height: 16,
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
  final void Function(String brandId) onBuy;

  const _RecentlyUsedSection({required this.onBuy});

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
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _buildRecentlyUsedItem(context, displayItems[index]),
                ),
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
    final imageUrl =
        item.imageUrl ??
        (item.brandId.isNotEmpty
            ? 'https://images.gift360.io/${item.brandId}.png'
            : null);
    return GestureDetector(
      onTap: () {
        if (item.brandId.isNotEmpty) onBuy(item.brandId);
      },
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
                    child: imageUrl != null
                        ? BrandImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const SizedBox(),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.store,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          )
                        : const Icon(
                            Icons.store,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Buy Again',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
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
}
