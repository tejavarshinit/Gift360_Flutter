import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Site footer — Flutter port of the React `Footer.tsx` used on the
/// Brands page (gift360.io). Mobile layout: flex-col, centered,
/// 12px muted text, top border, bg-muted/30, mt-12, certification
/// logo below a divider.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  // hsl(240 5% 50%) — Tailwind muted-foreground
  static const Color _mutedFg = Color(0xFF797986);

  // hsl(240 10% 92%) — Tailwind border
  static const Color _border = Color(0xFFE9E9ED);

  // hsl(240 10% 96%) at 30% — Tailwind bg-muted/30
  static const Color _bg = Color(0x4DF4F4F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 48), // mt-12
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 88), // px-4, pt-6, pb-20+
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── BRAND: gift icon + copyright ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.card_giftcard, size: 16, color: _mutedFg),
              ),
              const SizedBox(width: 16), // gap-4
              Flexible(
                child: Text(
                  '© 2024 One78 SabbPe Technology Solutions India Pvt. Ltd',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.4, color: _mutedFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // gap-4

          // ── LINKS ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink(label: 'Privacy Policy', path: '/privacy'),
              const SizedBox(width: 16),
              _FooterLink(label: 'Terms & Conditions', path: '/terms'),
              const SizedBox(width: 16),
              _FooterLink(label: 'Refund Policy', path: '/refund'),
            ],
          ),
          const SizedBox(height: 16), // gap-4

          // ── COPYRIGHT ──
          Text(
            'All rights reserved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: _mutedFg),
          ),

          const SizedBox(height: 24), // mt-6

          // ── CERTIFICATION LOGO ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 24), // pt-6
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border, width: 1)),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/certf logo.png',
                height: 40, // h-10
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final String path;

  const _FooterLink({required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(path),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12, color: SiteFooter._mutedFg),
      ),
    );
  }
}
