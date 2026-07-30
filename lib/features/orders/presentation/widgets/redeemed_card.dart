import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/orders/presentation/providers/orders_provider.dart';

class RedeemedCard extends StatelessWidget {
  final RedeemedEntry item;

  const RedeemedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    String dateStr = '';
    final d = DateTime.tryParse(item.redeemedAt);
    if (d != null) dateStr = 'Redeemed ${DateFormat('MM/yyyy - hh:mma').format(d)}';

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
            child: (item.image != null && item.image!.isNotEmpty)
                ? BrandImage(
                    imageUrl: item.image!,
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
                Text(item.brandName,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('₹${item.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('REDEEMED',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
                ),
                if (item.vouchers.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...item.vouchers.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      v.cardNumber.isNotEmpty ? v.cardNumber : '—',
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF888888)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                ],
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
