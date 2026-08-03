import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/payment/presentation/widgets/add_to_cart_success_modal.dart';

class PaymentDetailsSheet extends StatefulWidget {
  final Brand? brand;
  final bool loading;
  final bool processing;
  final String? error;
  final VoidCallback onClose;
  final void Function(Brand brand, double amount, int quantity) onAddToCart;
  final void Function(Brand brand, double amount, int quantity) onPay;

  const PaymentDetailsSheet({
    super.key,
    required this.brand,
    this.loading = false,
    this.processing = false,
    this.error,
    required this.onClose,
    required this.onAddToCart,
    required this.onPay,
  });

  @override
  State<PaymentDetailsSheet> createState() => _PaymentDetailsSheetState();
}

class _PaymentDetailsSheetState extends State<PaymentDetailsSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedAmount;
  int _quantity = 1;
  String _infoTab = '';
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _close() {
    _slideController.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.brand;

    if (widget.loading || brand == null) {
      final topPadding = MediaQuery.of(context).padding.top;
      final navBarHeight = topPadding + 56;
      return GestureDetector(
        onTap: _close,
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {},
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height - navBarHeight,
                margin: EdgeInsets.only(top: navBarHeight),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: Center(
                  child: widget.error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 34, color: Color(0xFFEF4444)),
                              const SizedBox(height: 12),
                              Text(
                                widget.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _close,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C5CE7),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                            SizedBox(height: 12),
                            Text(
                              'Loading payment details...',
                              style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isFixed = (brand.brandType ?? '').toLowerCase() == 'fixed';
    final minPrice = brand.effectiveStartingPrice;
    final maxPrice = brand.maxPrice ?? 0;
    final denominations = _parseDenominations(brand.denominationList ?? brand.denomination);

    // Auto-select when minPrice == maxPrice (single fixed price, e.g. "299-299")
    if (minPrice > 0 && minPrice == maxPrice && (_selectedAmount == null || _selectedAmount!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedAmount = minPrice.toInt().toString());
      });
    }
    // Auto-select first denomination for Fixed brands with denominations
    if (isFixed && denominations.isNotEmpty && (_selectedAmount == null || _selectedAmount!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedAmount = denominations.first.toInt().toString());
      });
    }

    final amount = double.tryParse(_selectedAmount ?? '') ?? 0;
    final total = amount * _quantity;
    final discount = double.tryParse(brand.discount ?? '0') ?? 0;
    final cashback = total > 0 ? (total * discount / 100).toInt() : 0;
    final isValid = _selectedAmount != null && _selectedAmount!.isNotEmpty;

    final topPadding = MediaQuery.of(context).padding.top;
    final navBarHeight = topPadding + 56;

    return GestureDetector(
      onTap: _close,
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: SlideTransition(
            position: _slideAnimation,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height - navBarHeight,
                margin: EdgeInsets.only(top: navBarHeight),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _close,
                            child: const Icon(Icons.chevron_left, size: 24, color: Color(0xFF111827)),
                          ),
                          const SizedBox(width: 8),
                          const Text('Payment Details',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          children: [
                            _buildBrandCard(brand),
                            const SizedBox(height: 16),
                            _buildAmountSelection(brand, isFixed, denominations, minPrice, maxPrice),
                            if (cashback > 0 && isValid) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+ ₹$cashback cashback',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      width: 60,
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _buildQuantitySection(amount),
                            const SizedBox(height: 16),
                            _buildInfoTabs(brand),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomBar(brand, total, cashback, isValid),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandCard(Brand brand) {
    final discount = brand.discount ?? '';
    final imageUrl = brand.resolvedImageUrl;
    return SizedBox(
      width: 342,
      height: 86,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageUrl != null
                  ? BrandImage(imageUrl: imageUrl, fit: BoxFit.contain)
                  : const Icon(Icons.store, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.brandName ?? 'Brand',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text('E-Gift Cards',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF78DEFF), Color(0xFF488599)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      brand.category ?? 'Gift Card',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            if (discount.isNotEmpty)
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                  ),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$discount%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSelection(
      Brand brand, bool isFixed, List<double> denominations, double minPrice, double maxPrice) {
    final discountPercent = double.tryParse(brand.discount ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Amount', style: TextStyle(fontSize: 12, fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.black)),
          if (minPrice > 0 && minPrice == maxPrice) ...[
            const SizedBox(height: 4),
            _denomPill(minPrice, active: true, onTap: null),
            const SizedBox(height: 4),
            _cashbackRow((minPrice * discountPercent / 100).round()),
          ] else if (isFixed) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: denominations.map((d) {
                final isSelected = _selectedAmount == d.toInt().toString();
                return GestureDetector(
                  onTap: () => setState(() => _selectedAmount = d.toInt().toString()),
                  child: AnimatedScale(
                    scale: isSelected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: const BoxConstraints(minWidth: 0),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF9747FF) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF9747FF) : const Color(0xFFDAD5FF),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '₹${d.toInt()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF3E3E3E),
                      ),
                    ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            if (_selectedAmount != null)
              _cashbackRow(((double.tryParse(_selectedAmount!) ?? 0) * discountPercent / 100).round()),
          ] else ...[
            _buildVariableAmountSlider(minPrice, maxPrice, discountPercent),
          ],
        ],
      ),
    );
  }

  Widget _cashbackRow(int cashback) {
    if (cashback <= 0) return const SizedBox.shrink();
    return Row(
      children: [
        Text(
          '+₹$cashback cashback',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _denomPill(double denom, {required bool active, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF9747FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFF9747FF) : const Color(0xFFDAD5FF), width: 2),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
              : const [],
        ),
        child: Text(
          '₹${denom.toInt()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF3E3E3E),
          ),
        ),
      ),
    );
  }

  /// Custom slider matching the reference app's `.payment-range` styling:
  /// a 10px rounded track (base #DAD5FF, active portion gradient
  /// #9747FF → #5B2B99), a 15px purple thumb with a white ring, a floating
  /// value bubble above the thumb, min/max labels, and a live cashback
  /// preview — since Flutter's stock Slider can't express any of that
  /// styling directly, the real Slider is rendered invisibly on top of a
  /// custom-painted track so dragging still works exactly like a native
  /// slider while the visuals match the reference pixel-for-pixel.
  Widget _buildVariableAmountSlider(double min, double max, double discountPercent) {
    final amount = (double.tryParse(_selectedAmount ?? '') ?? min).clamp(min, max <= min ? min + 1 : max);
    final effectiveMax = max > min ? max : min + 1;
    final percent = ((amount - min) / (effectiveMax - min)).clamp(0.0, 1.0);
    final cashback = (amount * discountPercent / 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final bubbleLeft = (percent * trackWidth).clamp(20.0, trackWidth - 20.0);
              return SizedBox(
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Floating value bubble
                    Positioned(
                      left: bubbleLeft - 20,
                      top: -22,
                      child: Container(
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F80ED),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Text(
                          amount.round().toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Gradient track
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: const [Color(0xFF9747FF), Color(0xFF5B2B99), Color(0xFFDAD5FF), Color(0xFFDAD5FF)],
                            stops: [0.0, percent, percent, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Invisible interactive slider (handles drag/a11y)
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 10,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbShape: const _RingThumbShape(),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        min: min,
                        max: effectiveMax,
                        value: amount,
                        onChanged: (v) => setState(() => _selectedAmount = v.round().toString()),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${min.toInt()}', style: const TextStyle(fontSize: 8, color: Colors.black)),
              Text('₹${max.toInt()}', style: const TextStyle(fontSize: 8, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '+₹$cashback cashback',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySection(double amount) {
    final total = amount * _quantity;
    final discount = double.tryParse(widget.brand?.discount ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Quantity:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => _quantity > 1 ? setState(() => _quantity--) : null,
                child: Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6C5CE7)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.remove, size: 18, color: Color(0xFF6C5CE7)),
                ),
              ),
              SizedBox(
                width: 48,
                child: Center(
                  child: Text('$_quantity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _quantity++),
                child: Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6C5CE7)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.add, size: 18, color: Color(0xFF6C5CE7)),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total: ₹${amount.toInt()} x $_quantity = ₹${total.toInt()}${discount > 0 ? ' + ₹${(total * discount / 100).toInt()} cashback' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6C5CE7)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTabs(Brand brand) {
    final hasAbout = brand.description != null && brand.description!.isNotEmpty;
    final hasHowToUse = brand.howToUse != null && brand.howToUse!.isNotEmpty;
    final hasTerms = brand.terms != null && brand.terms!.isNotEmpty;
    if (!hasAbout && !hasHowToUse && !hasTerms) return const SizedBox.shrink();

    return Column(
      children: [
        // Tab buttons row
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasAbout)
                _buildInfoTabButton('i', 'About', 'about', 71),
              if (hasHowToUse)
                _buildInfoTabButton('*', 'How to Use', 'howtouse', 102),
              if (hasTerms)
                _buildInfoTabButton('#', 'Terms', 'terms', 73),
            ],
          ),
        ),
        // Expandable content
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _infoTab == 'about' && hasAbout
              ? _buildInfoContent(brand.description!, false)
              : _infoTab == 'howtouse' && hasHowToUse
                  ? _buildInfoContent(brand.howToUse!, false)
                  : _infoTab == 'terms' && hasTerms
                      ? _buildInfoContent(brand.terms!, true)
                      : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildInfoTabButton(String symbol, String label, String tab, double width) {
    final isSelected = _infoTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _infoTab = isSelected ? '' : tab),
      child: Container(
        width: width,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEAFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF9747FF),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF9747FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContent(String content, bool isTerms) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(4, 4))],
        ),
        child: Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.5,
            color: const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  /// Shows the success animation (matches AddToCartSuccessModal.tsx) as an
  /// independent overlay route so it keeps playing/self-closes on its own
  /// timer even if the underlying sheet is torn down by the parent's
  /// (unchanged) onAddToCart flow immediately after this is called.
  void _showAddToCartSuccess(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent, // AddToCartSuccessModal paints its own dim backdrop
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });
        return AddToCartSuccessModal(
          open: true,
          onClose: () => Navigator.of(dialogContext).maybePop(),
        );
      },
    );
  }

  Widget _buildBottomBar(Brand brand, double total, int cashback, bool isValid) {
    final processing = widget.processing;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Add to Cart button
            Expanded(
              child: GestureDetector(
                onTap: (isValid && !processing)
                    ? () {
                        _showAddToCartSuccess(context);
                        widget.onAddToCart(brand, double.parse(_selectedAmount ?? '0'), _quantity);
                      }
                    : null,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: (isValid && !processing)
                        ? const LinearGradient(
                            colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: (isValid && !processing) ? null : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: processing ? 0.7 : 1.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Add to Cart',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Pay on Sabbpe button
            Expanded(
              child: GestureDetector(
                onTap: (isValid && !processing)
                    ? () => widget.onPay(brand, double.parse(_selectedAmount ?? '0'), _quantity)
                    : null,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: (isValid && !processing) ? Colors.white : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isValid && !processing) ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
                    ),
                    boxShadow: (isValid && !processing)
                        ? const [BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 4))]
                        : null,
                  ),
                  child: Center(
                    child: processing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9747FF)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Processing...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF9747FF),
                                ),
                              ),
                            ],
                          )
                        : Opacity(
                            opacity: (isValid && !processing) ? 1.0 : 0.5,
                            child: Image.asset(
                              'assets/images/payonsabbpe.png',
                              height: 22,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text(
                                'Pay on Sabbpe',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: (isValid && !processing) ? const Color(0xFF6C5CE7) : const Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
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

  List<double> _parseDenominations(String? denomination) {
    if (denomination == null || denomination.isEmpty) return [];
    return denomination
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }
}

/// Matches the reference app's `.payment-range::-webkit-slider-thumb`:
/// a 15px purple circle with a thin white ring around it.
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(15, 15);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      8.5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(center, 8.0, Paint()..color = Colors.white);
    canvas.drawCircle(center, 7.0, Paint()..color = const Color(0xFF6C5CE7));
  }
}
