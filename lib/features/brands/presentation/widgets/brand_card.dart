import 'package:flutter/material.dart';
import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/brands/data/models/brand.dart';

class BrandCard extends StatelessWidget {
  final Brand brand;
  final VoidCallback? onTap;

  const BrandCard({super.key, required this.brand, this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = brand.resolvedImageUrl;
    final brandName = brand.brandName ?? 'Brand';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: imageUrl != null
                  ? BrandImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, s) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (_, s, e) => const Icon(Icons.store, color: Color(0xFF94A3B8)),
                    )
                  : const Icon(Icons.store, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                brandName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF101010), height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
