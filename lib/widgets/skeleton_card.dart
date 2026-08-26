import 'package:flutter/material.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14262B4D), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Row(
        children: [
          _shimmerBox(64, 64, 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(128, 16, 8),
                const SizedBox(height: 8),
                _shimmerBox(80, 12, 8),
                const SizedBox(height: 8),
                _shimmerBox(64, 12, 8),
              ],
            ),
          ),
          _shimmerBox(56, 32, 999),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h, double radius) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(radius)),
    );
  }
}
