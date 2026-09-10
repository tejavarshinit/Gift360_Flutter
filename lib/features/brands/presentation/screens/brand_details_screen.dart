import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/guard_rails/presentation/providers/guard_rails_provider.dart';
import 'package:gift360/core/utils/analytics.dart';

class BrandDetailsScreen extends ConsumerStatefulWidget {
  final String brandId;

  const BrandDetailsScreen({super.key, required this.brandId});

  @override
  ConsumerState<BrandDetailsScreen> createState() => _BrandDetailsScreenState();
}

class _BrandDetailsScreenState extends ConsumerState<BrandDetailsScreen> {
  static const int _maxQuantityPerItem = 3;
  String? _selectedAmount;
  int _quantity = 1;
  String _error = '';
  bool _showInfoModal = false;
  String _infoTab = 'about';
  DateTime? _lastAddToCartClick;

  @override
  Widget build(BuildContext context) {
    final brandAsync = ref.watch(brandDetailsProvider(widget.brandId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: brandAsync.when(
        data: (brand) => _buildBrandDetails(brand),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(),
      ),
      bottomNavigationBar: brandAsync.maybeWhen(
        data: (brand) => _buildBottomBar(brand),
        orElse: () => null,
      ),
    );
  }

  Widget _buildBrandDetails(Brand brand) {
    // Track view_item event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.trackViewItem(
        brandId: brand.brandId ?? '',
        brandName: brand.brandName ?? '',
        category: brand.category,
        price: brand.effectiveStartingPrice,
      );
    });
    final isFixed = (brand.brandType ?? '').toLowerCase() == 'fixed';
    final minPrice = brand.effectiveStartingPrice;
    final maxPrice = brand.maxPrice ?? 0;
    final denominations = _parseDenominations(brand.denominationList ?? brand.denomination);

    // Auto-select when minPrice == maxPrice (single fixed price)
    if (minPrice > 0 && minPrice == maxPrice && (_selectedAmount == null || _selectedAmount!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedAmount = minPrice.toInt().toString());
      });
    }
    // Auto-select first denomination for Fixed brands
    if (isFixed && denominations.isNotEmpty && (_selectedAmount == null || _selectedAmount!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedAmount = denominations.first.toInt().toString());
      });
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              flexibleSpace: FlexibleSpaceBar(
                  background: brand.resolvedImageUrl != null
                      ? BrandImage(
                          imageUrl: brand.resolvedImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, s) => Container(color: const Color(0xFFE8E0F0)),
                          errorWidget: (_, s, e) => Container(
                            color: const Color(0xFFE8E0F0),
                            child: const Icon(Icons.store, size: 64, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                        color: const Color(0xFFE8E0F0),
                        child: const Icon(Icons.store, size: 64, color: Color(0xFF94A3B8)),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            brand.brandName ?? 'Brand',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                        ),
                        if (brand.discount != null && brand.discount!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${brand.discount}% Cashback',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    if (brand.category != null && brand.category!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(brand.category!, style: const TextStyle(fontSize: 12, color: Color(0xFF6C5CE7))),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (brand.description != null && brand.description!.isNotEmpty) ...[
                      const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(brand.description!, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
                      const SizedBox(height: 20),
                    ],
                    _buildPurchaseSection(brand, isFixed, minPrice, maxPrice, denominations),
                    const SizedBox(height: 20),
                    _buildInfoButtons(brand),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_showInfoModal) _buildInfoModal(brand),
      ],
    );
  }

  Widget _buildPurchaseSection(Brand brand, bool isFixed, double minPrice, double maxPrice, List<double> denominations) {
    final isValid = _isValidAmount(brand);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Purchase Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (isFixed) ...[
            const Text('Select a denomination', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            denominations.isNotEmpty
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: denominations.map((d) {
                      final isSelected = _selectedAmount == d.toInt().toString();
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedAmount = d.toInt().toString();
                          _error = '';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)])
                                : null,
                            color: isSelected ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                : [],
                          ),
                          child: Text(
                            '₹${d.toInt()}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                        ),
                       );
                    }).toList(),
                  )
                : const Text('No denominations available', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ] else ...[
            Text('₹${minPrice.toInt()} - ₹${maxPrice.toInt()}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              onChanged: (v) {
                setState(() {
                  _selectedAmount = v;
                  final num = double.tryParse(v);
                  if (num == null) {
                    _error = 'Enter a valid number';
                  } else if (num < minPrice) {
                    _error = 'Minimum amount is ₹${minPrice.toInt()}';
                  } else if (num > maxPrice) {
                    _error = 'Maximum amount is ₹${maxPrice.toInt()}';
                  } else {
                    _error = '';
                  }
                });
              },
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: '${minPrice.toInt()} - ${maxPrice.toInt()}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Text(_error, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildQuantityButton(Icons.remove, () {
                if (_quantity > 1) setState(() => _quantity--);
              }),
              Container(
                width: 48,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$_quantity', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              _buildQuantityButton(Icons.add, () {
                if (_quantity < _maxQuantityPerItem) setState(() => _quantity++);
              }),
            ],
          ),
          if (isValid && _error.isEmpty) ...[
            const SizedBox(height: 16),
            _buildCashbackCard(brand),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildCashbackCard(Brand brand) {
    final amount = double.tryParse(_selectedAmount ?? '0') ?? 0;
    final discount = double.tryParse(brand.discount ?? '0') ?? 0;
    final total = amount * _quantity;
    final cashback = (total * discount / 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Icons.trending_up, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CASHBACK EARNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text('$cashback Points', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${discount.toInt()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                const Text('CASH', style: TextStyle(fontSize: 6, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButtons(Brand brand) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (brand.description != null)
            _buildInfoButton(Icons.info_outline, 'About', 'about', const Color(0xFF6C5CE7)),
          if (brand.howToUse != null)
            _buildInfoButton(Icons.book_outlined, 'Redeem', 'redeem', const Color(0xFF6C5CE7)),
          if (brand.terms != null)
            _buildInfoButton(Icons.description_outlined, 'T & C', 'terms', const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildInfoButton(IconData icon, String label, String tab, Color color) {
    return GestureDetector(
      onTap: () => setState(() {
        _infoTab = tab;
        _showInfoModal = true;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoModal(Brand brand) {
    final tabs = [
      {'key': 'about', 'label': 'About', 'icon': Icons.info_outline},
      {'key': 'redeem', 'label': 'How to Redeem', 'icon': Icons.redeem},
      {'key': 'instructions', 'label': 'Instructions', 'icon': Icons.warning_amber_outlined},
      {'key': 'terms', 'label': 'T&C', 'icon': Icons.description_outlined},
    ];

    return GestureDetector(
      onTap: () => setState(() => _showInfoModal = false),
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Brand Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => setState(() => _showInfoModal = false), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  // Tab bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: tabs.map((tab) {
                        final isActive = _infoTab == tab['key'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _infoTab = tab['key'] as String),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isActive ? const Color(0xFF523DA9) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(tab['icon'] as IconData, size: 18,
                                      color: isActive ? const Color(0xFF523DA9) : Colors.grey),
                                  const SizedBox(height: 4),
                                  Text(tab['label'] as String,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                          color: isActive ? const Color(0xFF523DA9) : Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildInfoContent(brand),
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

  Widget _buildInfoContent(Brand brand) {
    switch (_infoTab) {
      case 'about':
        return Text(brand.description ?? 'No description available.', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)));
      case 'redeem':
        return Text(brand.howToUse ?? 'No redemption steps available.', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)));
      case 'instructions':
        final instructions = brand.importantInstruction;
        if (instructions == null || instructions.toString().trim().isEmpty) {
          return const Text('No special instructions for this brand.', style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)));
        }
        return Text(instructions.toString(), style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)));
      case 'terms':
        return Text(brand.terms ?? 'No terms available.', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar(Brand brand) {
    final amount = double.tryParse(_selectedAmount ?? '0') ?? 0;
    final total = amount * _quantity;
    final isValid = _selectedAmount != null && _selectedAmount!.isNotEmpty && _error.isEmpty;

    // Guard rail check
    final guardRailAsync = ref.watch(brandGuardRailProvider(brand.brandId ?? ''));
    final guardRail = guardRailAsync.valueOrNull;
    final wouldExceed = guardRail != null && guardRail.hasGuardRail &&
        (guardRail.currentUsage + total) > guardRail.monthlyLimit;
    final nearLimit = guardRail != null && guardRail.hasGuardRail &&
        guardRail.remaining > 0 && guardRail.remaining <= guardRail.monthlyLimit * 0.2;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Guard rail status
          if (guardRail != null && guardRail.hasGuardRail) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: wouldExceed ? const Color(0xFFFEF2F2) : nearLimit ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: wouldExceed ? const Color(0xFFFECACA) : nearLimit ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Icon(
                    wouldExceed ? Icons.warning_amber_rounded : nearLimit ? Icons.info_outline : Icons.check_circle_outline,
                    size: 16,
                    color: wouldExceed ? const Color(0xFFDC2626) : nearLimit ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wouldExceed
                          ? 'Guard rail limit exceeded. Remaining: ₹${guardRail.remaining.toInt()}'
                          : nearLimit
                              ? 'Guard rail limit low. Remaining: ₹${guardRail.remaining.toInt()} of ₹${guardRail.monthlyLimit.toInt()}'
                              : 'Guard rail: ₹${guardRail.currentUsage.toInt()} used of ₹${guardRail.monthlyLimit.toInt()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: wouldExceed ? const Color(0xFFDC2626) : nearLimit ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (isValid && !wouldExceed) ? () => _handleAddToCart(brand, amount) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: (isValid && !wouldExceed) ? const Color(0xFF6C5CE7) : const Color(0xFFD1D5DB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                wouldExceed
                    ? 'Guard Rail Limit Exceeded'
                    : isValid
                        ? 'Add ₹${total.toInt()} to Cart'
                        : 'Select Amount',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAddToCart(Brand brand, double amount) {
    final now = DateTime.now();
    if (_lastAddToCartClick != null &&
        now.difference(_lastAddToCartClick!).inMilliseconds < 800) {
      return;
    }
    _lastAddToCartClick = now;

    final isAuthenticated = ref.read(authProvider) != null;

    ref.read(cartProvider.notifier).addToCart(AddToCartRequest(
          brandId: brand.brandId ?? '',
          brandName: brand.brandName ?? '',
          quantity: _quantity,
          unitValue: amount,
          image: brand.resolvedImageUrl,
        ));

    final quantity = _quantity;
    final brandName = brand.brandName ?? 'voucher';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAuthenticated
              ? '${quantity}x $brandName voucher(s) of ₹${amount.toInt()} each added to cart'
              : '${quantity}x $brandName voucher(s) saved. Login to checkout.',
        ),
      ),
    );

    setState(() {
      _quantity = 1;
      final isFixed = (brand.brandType ?? '').toLowerCase() == 'fixed';
      if (!isFixed) _selectedAmount = '';
    });
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          const Text('Could not load brand details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.go('/brands'),
            child: const Text('Go Back to Brands'),
          ),
        ],
      ),
    );
  }

  List<double> _parseDenominations(String? denomination) {
    if (denomination == null || denomination.isEmpty) return [];
    return denomination.split(',').map((e) => double.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList();
  }

  bool _isValidAmount(Brand brand) {
    if (_selectedAmount == null || _selectedAmount!.isEmpty) return false;
    final amount = double.tryParse(_selectedAmount!);
    if (amount == null || amount <= 0) return false;
    final isFixed = (brand.brandType ?? '').toLowerCase() == 'fixed';
    if (isFixed) {
      final denominations = _parseDenominations(brand.denominationList ?? brand.denomination);
      return denominations.any((d) => d.toInt() == amount.toInt());
    }
    final minPrice = brand.effectiveStartingPrice;
    final maxPrice = brand.maxPrice ?? 0;
    return amount >= minPrice && amount <= maxPrice;
  }
}
