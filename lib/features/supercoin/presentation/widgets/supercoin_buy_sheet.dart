import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/payment/presentation/widgets/payment_details_sheet.dart';
import 'package:gift360/core/providers/notification_provider.dart';

/// Standard buy sheet opened from the SuperCoin header icon, with the
/// Flipkart B2C brand pre-selected (matches React flow: header icon →
/// buy sheet → add to cart → /cart, NOT a standalone modal).
class SuperCoinBuySheet extends ConsumerStatefulWidget {
  const SuperCoinBuySheet({super.key});

  @override
  ConsumerState<SuperCoinBuySheet> createState() => _SuperCoinBuySheetState();
}

class _SuperCoinBuySheetState extends ConsumerState<SuperCoinBuySheet> {
  Brand? _brand;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBrand();
  }

  Future<void> _fetchBrand() async {
    try {
      final api = ref.read(brandsApiProvider);
      final details = await api.getBrandDetailsById(SuperCoinConversionConfig.featuredBrandId);
      if (!mounted) return;
      setState(() { _brand = details; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
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
    Navigator.of(context).pop();
    // Navigate to the Cart tab
    context.go('/cart');
  }

  void _handlePay(Brand brand, double amount, int quantity) {
    // Standard payment flow — reuse the home screen's payment logic via cart.
    _handleAddToCart(brand, amount, quantity);
  }

  @override
  Widget build(BuildContext context) {
    return PaymentDetailsSheet(
      brand: _brand,
      loading: _loading,
      processing: false,
      error: _error,
      onClose: () => Navigator.of(context).pop(),
      onAddToCart: _handleAddToCart,
      onPay: _handlePay,
    );
  }
}

/// Opens the SuperCoin buy sheet with the Flipkart B2C brand pre-selected.
/// Checks the kill switch first — if paused, shows a toast and stops.
void openSuperCoinBuySheet(BuildContext context) {
  if (SuperCoinConversionConfig.paused) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SuperCoinConversionConfig.pausedMessage)),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SuperCoinBuySheet(),
  );
}
