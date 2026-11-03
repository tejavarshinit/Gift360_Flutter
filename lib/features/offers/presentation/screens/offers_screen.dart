import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/core/widgets/brand_image.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';

/// `/offers` — hot deals: brands sorted by discount (matches React `Offers.tsx`).
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(brandsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    icon: const Icon(Icons.chevron_left, size: 26),
                  ),
                  Text('Hot Deals', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: brandsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9747FF))),
                error: (_, __) => Center(
                  child: Text('Could not load offers', style: GoogleFonts.poppins(color: const Color(0xFF6B7280))),
                ),
                data: (brands) {
                  final deals = brands
                      .where((b) => _discountOf(b) > 0)
                      .toList()
                    ..sort((a, b) => _discountOf(b).compareTo(_discountOf(a)));
                  final top = deals.take(24).toList();
                  if (top.isEmpty) {
                    return Center(
                      child: Text('No offers right now', style: GoogleFonts.poppins(color: const Color(0xFF6B7280))),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: top.length,
                    itemBuilder: (context, index) => _dealCard(context, top[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _discountOf(Brand brand) => double.tryParse(brand.discount ?? '') ?? 0;

  Widget _dealCard(BuildContext context, Brand brand) {
    final discount = _discountOf(brand).round();
    return GestureDetector(
      onTap: () {
        final id = brand.brandId;
        if (id != null && id.isNotEmpty) context.push('/brand/$id');
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: BrandImage(imageUrl: brand.resolvedImageUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              brand.brandName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (discount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$discount% off',
                        style: GoogleFonts.poppins(
                            fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                  ),
                const Spacer(),
                Text('\u20b9${(brand.minPrice ?? 0).toStringAsFixed(0)}+',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
