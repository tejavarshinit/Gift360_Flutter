import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/brands/data/models/brand.dart';

/// Port of `components/BrandVoucherModal.tsx` — the bottom-sheet voucher
/// list shown when a Top Brands tile is tapped. Includes the 300ms
/// ease-out slide-up entrance (`.animate-slide-up` in the reference app)
/// and the 4px backdrop blur, both missing from the previous version.
class BrandVoucherModal extends StatefulWidget {
  final bool isOpen;
  final String brandName;
  final List<Brand> vouchers;
  final bool loading;
  final String? error;
  final VoidCallback? onClose;
  final VoidCallback? onRetry;
  final Function(Brand)? onVoucherSelect;

  const BrandVoucherModal({
    super.key,
    required this.isOpen,
    required this.brandName,
    this.vouchers = const [],
    this.loading = false,
    this.error,
    this.onClose,
    this.onRetry,
    this.onVoucherSelect,
  });

  @override
  State<BrandVoucherModal> createState() => _BrandVoucherModalState();
}

class _BrandVoucherModalState extends State<BrandVoucherModal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isOpen) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant BrandVoucherModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _controller.forward(from: 0);
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (screenHeight * 0.72).clamp(560.0, double.infinity);

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Container(
                      width: double.infinity,
                      height: sheetHeight,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -4))],
                      ),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 100,
                            height: 10,
                            decoration: BoxDecoration(color: const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(5)),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: widget.onClose,
                                  child: const Icon(Icons.chevron_left, size: 24),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.brandName.isNotEmpty ? widget.brandName : 'Brand Vouchers',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF3E3E3E)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: _buildContent()),
                        ],
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

  Widget _buildContent() {
    if (widget.loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7C3AED)),
            SizedBox(height: 12),
            Text('Loading vouchers...', style: TextStyle(fontSize: 14, color: Color(0xFF667085))),
          ],
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Color(0xFFFEE4E2), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline, color: Color(0xFFB42318), size: 22),
              ),
              const SizedBox(height: 12),
              const Text('Unable to load vouchers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(widget.error!, style: const TextStyle(fontSize: 12, color: Color(0xFF667085)), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.vouchers.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No vouchers available', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Please try another brand.', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Vouchers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Choose a voucher to continue to payment', style: TextStyle(fontSize: 11, color: Color(0xFF667085))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))]),
                child: Text('${widget.vouchers.length} options', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475467))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: widget.vouchers.length,
              separatorBuilder: (_, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final voucher = widget.vouchers[index];
                return _buildVoucherCard(voucher);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Brand voucher) {
    final price = voucher.effectiveStartingPrice;
    return GestureDetector(
      onTap: () => widget.onVoucherSelect?.call(voucher),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0F0F1A2E), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: voucher.resolvedImageUrl != null
                  ? BrandImage(
                      imageUrl: voucher.resolvedImageUrl!,
                      fit: BoxFit.contain,
                      placeholder: (_, s) => const SizedBox(),
                      errorWidget: (_, s, e) => const Icon(Icons.store, color: Color(0xFF94A3B8)),
                    )
                  : const Icon(Icons.store, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voucher.brandName ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF101828)), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(voucher.category ?? 'Gift Voucher', style: const TextStyle(fontSize: 12, color: Color(0xFF667085)), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${price.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                      Text(
                        voucher.discount != null && voucher.discount!.isNotEmpty ? '${voucher.discount}% Cashback' : 'Cashback',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF7C3AED)),
                      ),
                    ],
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
