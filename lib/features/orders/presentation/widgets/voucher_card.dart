import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';
import 'package:gift360/features/orders/presentation/widgets/redeem_sheet.dart';
import 'package:gift360/features/orders/presentation/widgets/scratch_card.dart';
import 'package:gift360/features/gifting/presentation/providers/gifting_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Voucher card — matches React Orders.tsx OrderCard layout exactly:
/// centered column with 64×64 image on top, brand name, price, full-width
/// Redeem button, date, and "View Vouchers" toggle.
class VoucherCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final String clientId;
  final bool expanded;
  final bool isSuperCoin;
  final VoidCallback onToggle;
  final Future<void> Function(List<VoucherView> vouchers) onRedeemed;

  const VoucherCard({
    super.key,
    required this.order,
    required this.clientId,
    required this.expanded,
    this.isSuperCoin = false,
    required this.onToggle,
    required this.onRedeemed,
  });

  @override
  ConsumerState<VoucherCard> createState() => _VoucherCardState();
}

class _VoucherCardState extends ConsumerState<VoucherCard> {
  final Set<String> _revealedKeys = {};
  Map<String, List<Map<String, dynamic>>> _cardItemsByOrderItem = {};

  @override
  void initState() {
    super.initState();
    _loadCardItems();
  }

  @override
  void didUpdateWidget(covariant VoucherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order['order_number'] != widget.order['order_number'] ||
        oldWidget.clientId != widget.clientId) {
      _loadCardItems();
    }
  }

  Future<void> _loadCardItems() async {
    final items = widget.order['items'];
    if (items is! List) return;
    final api = ref.read(giftingApiProvider);
    final loaded = <String, List<Map<String, dynamic>>>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final orderItemId = raw['order_item_id']?.toString() ?? '';
      if (orderItemId.isEmpty) continue;
      try {
        loaded[orderItemId] = await api.getCardItems(
          widget.clientId,
          orderItemId,
        );
      } catch (_) {
        // The order-level flags remain the fallback if this endpoint is unavailable.
      }
    }
    if (mounted) setState(() => _cardItemsByOrderItem = loaded);
  }

  @override
  Widget build(BuildContext context) {
    final meta = firstItemMeta(widget.order);
    final brandName = orderBrandName(widget.order);
    final imageUrl = orderItemImageUrl(meta);
    final redeemSteps = orderRedeemSteps(widget.order);
    final vouchers = extractVouchers(
      widget.order,
      cardItemsByOrderItem: _cardItemsByOrderItem,
    );
    final paidAmount = orderTotalAmount(widget.order);
    final createdAt = orderCreatedAt(widget.order);
    String dateStr = '';
    if (createdAt != null) {
      final d = DateTime.tryParse(createdAt);
      if (d != null) dateStr = DateFormat('MM/yyyy - hh:mma').format(d);
    }
    final orderNumber = widget.order['order_number']?.toString() ?? '';
    final anyRevealed = vouchers.any((v) => _revealedKeys.contains(v.key));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main card (centered column — matches React OrderCard) ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1F000000),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: -6,
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Brand logo (64×64 centered)
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
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
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.storefront,
                          color: Color(0xFF94A3B8),
                          size: 32,
                        ),
                      )
                    : const Icon(
                        Icons.storefront,
                        color: Color(0xFF94A3B8),
                        size: 32,
                      ),
              ),
              const SizedBox(height: 8),

              // Brand name (11px semibold, centered, truncated)
              Text(
                brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),

              // SuperCoin badge (only for SuperCoin orders)
              if (widget.isSuperCoin)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/SuperCOin-removebg-preview.png',
                      width: 14,
                      height: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'SuperCoins',
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7B5CFF),
                      ),
                    ),
                  ],
                ),

              // Amount (10px)
              Text(
                '₹${paidAmount.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),

              // Redeem button (only after ≥1 card revealed)
              if (anyRevealed) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showRedeemSheet(
                      context,
                      vouchers: vouchers,
                      brandName: brandName,
                      redeemSteps: redeemSteps,
                    );
                    if (confirmed == true) {
                      await widget.onRedeemed(vouchers);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6354D3), Color(0xFF7B5CFF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Redeem',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],

              // Date (7px)
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 7,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF5E5E5E),
                    height: 2.5,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Toggle (matches React: centered "Hide"/"View Vouchers" at 10px) ──
        GestureDetector(
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 12,
                  color: const Color(0xFF7B5CFF),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.expanded ? 'Hide' : 'View Vouchers',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7B5CFF),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Expanded voucher codes (full-width revealed card, matches React) ──
        if (widget.expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: vouchers.isNotEmpty
                ? Column(
                    children: List.generate(vouchers.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ScratchCard(
                          key: ValueKey(vouchers[i].key),
                          voucher: vouchers[i],
                          clientId: widget.clientId,
                          orderNumber: orderNumber,
                          index: i,
                          onStateChange: (state) {
                            if (state != VoucherState.pending) {
                              setState(
                                () => _revealedKeys.add(vouchers[i].key),
                              );
                            }
                          },
                        ),
                      );
                    }),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '⏳ Generating...',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
