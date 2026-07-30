import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';
import 'package:gift360/features/orders/presentation/widgets/redeem_sheet.dart';
import 'package:gift360/features/orders/presentation/widgets/scratch_card.dart';

class VoucherCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String clientId;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(List<VoucherView> vouchers) onRedeemed;

  const VoucherCard({
    super.key,
    required this.order,
    required this.clientId,
    required this.expanded,
    required this.onToggle,
    required this.onRedeemed,
  });

  @override
  Widget build(BuildContext context) {
    final meta = firstItemMeta(order);
    final brandName = orderBrandName(order);
    final imageUrl = orderItemImageUrl(meta);
    final redeemSteps = orderRedeemSteps(order);
    final vouchers = extractVouchers(order);
    final paidAmount = orderTotalAmount(order);
    final createdAt = orderCreatedAt(order);
    String dateStr = '';
    if (createdAt != null) {
      final d = DateTime.tryParse(createdAt);
      if (d != null) dateStr = DateFormat('MM/yyyy - hh:mma').format(d);
    }
    final orderNumber = order['order_number']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, -6),
                spreadRadius: -6,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 88,
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
                        errorWidget: (_, __, ___) => const Icon(Icons.storefront, color: Color(0xFF94A3B8)),
                      )
                    : const Icon(Icons.storefront, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(brandName,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('₹${paidAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        final confirmed = await showRedeemSheet(
                          context,
                          vouchers: vouchers,
                          brandName: brandName,
                          redeemSteps: redeemSteps,
                        );
                        if (confirmed == true) {
                          await onRedeemed(vouchers);
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6354D3), Color(0xFF7B5CFF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Redeem',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(dateStr, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w400, color: const Color(0xFF5E5E5E))),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Expand/Collapse toggle
        GestureDetector(
          onTap: onToggle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 14,
                  color: const Color(0xFF7B5CFF),
                ),
                const SizedBox(width: 4),
                Text(
                  expanded ? 'Hide Vouchers' : 'View Vouchers',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7B5CFF),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded voucher codes with AnimatedCrossFade
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: vouchers.isNotEmpty
                ? Column(
                    children: List.generate(vouchers.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ScratchCard(
                          key: ValueKey(vouchers[i].key),
                          voucher: vouchers[i],
                          clientId: clientId,
                          orderNumber: orderNumber,
                          index: i,
                        ),
                      );
                    }),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Text(
                      '⏳ Vouchers are being generated. Please refresh in a moment.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
          ),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
