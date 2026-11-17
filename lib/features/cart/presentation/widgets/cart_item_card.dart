import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/widgets/brand_image.dart';

class CartItemCard extends StatelessWidget {
  final String itemId;
  final String brandName;
  final String? image;
  final int quantity;
  final double unitValue;
  final double lineTotal;
  final void Function(String itemId, int newQuantity) onQuantityChange;
  final void Function(String itemId) onRemove;

  const CartItemCard({
    super.key,
    required this.itemId,
    required this.brandName,
    this.image,
    required this.quantity,
    required this.unitValue,
    required this.lineTotal,
    required this.onQuantityChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: image != null && image!.isNotEmpty
                ? BrandImage(
                    imageUrl: image,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6D5AE6),
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.store, color: Color(0xFF94A3B8)),
                  )
                : const Icon(Icons.store, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand name + delete button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brandName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D2D2D),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${unitValue.toStringAsFixed(2)} each',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onRemove(itemId),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quantity stepper + line total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Minus button
                        GestureDetector(
                          onTap: quantity > 1 ? () => onQuantityChange(itemId, quantity - 1) : null,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA29BFE).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFD7BDFF)),
                            ),
                            child: const Icon(Icons.remove, size: 12, color: Color(0xFF2D2D2D)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quantity
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$quantity',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Plus button (capped at 3 — matches React MAX_QUANTITY_PER_ITEM)
                        GestureDetector(
                          onTap: quantity >= 3 ? null : () => onQuantityChange(itemId, quantity + 1),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA29BFE).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFD7BDFF)),
                            ),
                            child: const Icon(Icons.add, size: 12, color: Color(0xFF2D2D2D)),
                          ),
                        ),
                      ],
                    ),
                    // Line total
                    Text(
                      '₹${lineTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9747FF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
