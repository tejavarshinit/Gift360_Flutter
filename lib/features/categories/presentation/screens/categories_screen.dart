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
      setState(() {
        _paymentBrand = details;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to make a payment')),
        );
      }
      return;
    }

    final brandId = brand.brandId ?? '';
    if (brandId.isEmpty) return;

    setState(() {
      _showPaymentSheet = false;
      _paymentBrand = null;
    });

    final totalAmount = amount * quantity;
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
      if (!mounted || orderNumber == null) return;

      final valid = await paymentNotifier.validateOrder(
        cartTotal: totalAmount,
        walletAmount: 0,
        walletUsed: false,
      );
      if (!mounted || !valid) return;

      final tokenOk = await paymentNotifier.generateToken();
      if (!mounted || !tokenOk) return;

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
      if (!mounted || !initiated) return;

      final paymentUrl = ref.read(paymentProvider).initiateResponse?.paymentUrl;
      if (paymentUrl != null && mounted) {
        context.push('/payment-webview', extra: {
          'paymentUrl': paymentUrl,
          'orderNumber': orderNumber,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(allBrandsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Page background gradient (179.64deg)
          Positioned.fill(
            child: Container(
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
            ),
          ),
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: brandsAsync.when(
                  data: (brands) => _buildCategoryList(brands),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
          if (_showPaymentSheet)
            PaymentDetailsSheet(
              brand: _paymentBrand,
              loading: _paymentLoading,
              processing: false,
              error: _paymentError,
              onClose: () => setState(() {
                _showPaymentSheet = false;
                _paymentBrand = null;
                _paymentLoading = false;
                _paymentError = null;
              }),
              onAddToCart: (brand, amount, quantity) async {
                ref.read(cartProvider.notifier).addToCart(AddToCartRequest(
                      brandId: brand.brandId!,
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
                  _paymentBrand = null;
                });
                await Future.delayed(const Duration(milliseconds: 2200));
                if (mounted) {
                  StatefulNavigationShell.of(context).goBranch(3);
                }
              },
              onPay: (brand, amount, quantity) => _handlePay(brand, amount, quantity),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header (Section 3A)
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
                  'Categories',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
  // Category List
  // ─────────────────────────────────────────────
  Widget _buildCategoryList(List<Brand> brands) {
    final filterMetaAsync = ref.watch(filterMetaProvider);
    final categoryNames = filterMetaAsync.when(
      data: (meta) => meta.categories.isNotEmpty ? meta.categories : _extractCategories(brands),
      loading: () => _extractCategories(brands),
      error: (_, __) => _extractCategories(brands),
    );

    final categoryMap = <String, List<Brand>>{};
    for (final brand in brands) {
      final category = brand.category ?? 'Other';
      categoryMap.putIfAbsent(category, () => []).add(brand);
    }

    if (categoryNames.isEmpty) {
      return const Center(child: Text('No categories available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
      itemCount: categoryNames.length,
      itemBuilder: (context, index) {
        final category = categoryNames[index];
        final categoryBrands = categoryMap[category] ?? [];
        if (categoryBrands.isEmpty) return const SizedBox.shrink();
        return _buildCategorySection(category, categoryBrands);
      },
    );
  }

  List<String> _extractCategories(List<Brand> brands) {
    final categories = <String>{};
    for (final brand in brands) {
      final category = brand.category?.trim();
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }
    final list = categories.toList()..sort();
    return list;
  }

  // ─────────────────────────────────────────────
  // Category Section (Section 3B)
  // ─────────────────────────────────────────────
  Widget _buildCategorySection(String title, List<Brand> brands) {
    final displayBrands = brands.take(8).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: displayBrands.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _buildProductCard(displayBrands[index]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Product Card (Section 3C) — variant: 'category'
  // ─────────────────────────────────────────────
  Widget _buildProductCard(Brand brand) {
    final imageUrl = brand.resolvedImageUrl;
    final brandName = brand.brandName ?? '';
    final price = brand.effectiveStartingPrice;

    return Container(
        width: 120,
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
              spreadRadius: -1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top section: image + name
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null
                      ? BrandImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) => const SizedBox(),
                        )
                      : const SizedBox(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brandName,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'E-Gift Card',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Divider
            Divider(
              color: AppColors.divider,
              thickness: 1,
              height: 20,
            ),

            // Bottom section: price + buy button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  price > 0 ? '₹${price.toInt()}' : '-',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (brand.brandId != null && brand.brandId!.isNotEmpty) {
                      _openBuySheet(brand.brandId!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.buyButtonGradient,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                ),
              ],
            ),
          ],
        ),
      );
  }
}
