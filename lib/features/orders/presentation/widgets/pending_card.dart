import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';

class PendingCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const PendingCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final meta = firstItemMeta(order);
    final brandName = orderBrandName(order);
    final imageUrl = orderItemImageUrl(meta);
    final amount = orderTotalAmount(order);
    final createdAt = orderCreatedAt(order);
    String dateStr = '';
    if (createdAt != null) {
      final d = DateTime.tryParse(createdAt);
      if (d != null) dateStr = DateFormat('MM/yyyy - hh:mma').format(d);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA1A1A1), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(4, 4),
            blurRadius: 4,
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
              children: [
                Text(brandName,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('₹${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 9, color: Color(0xFF92400E)),
                      const SizedBox(width: 4),
                      Text('PENDING',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please go to cart to retry payment for this order.'),
                      duration: Duration(seconds: 3),
                    ));
                  },
                  child: Container(
                    width: 100,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFD79A8), Color(0xFFB96BC6), Color(0xFF6C5CE7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.replay, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Retry', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(dateStr, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w400, color: const Color(0xFF5E5E5E))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
