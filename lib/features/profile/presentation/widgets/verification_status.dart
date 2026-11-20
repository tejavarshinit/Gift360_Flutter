import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _green = Color(0xFF047857); // emerald-700 (matches React)
const _grey = Color(0xFFA59BBE);

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 12, color: _green),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches React `VerificationRow`: a small grey tile with the label on the
/// left and the status (tick / cross) on the right.
class VerificationStatusRow extends StatelessWidget {
  final String label;
  final bool verified;

  const VerificationStatusRow({
    super.key,
    required this.label,
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    final color = verified ? _green : _grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF81789A),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                verified ? Icons.check_rounded : Icons.close_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                verified ? 'Verified' : 'Not verified',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
