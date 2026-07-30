import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeleteConfirmDialog extends StatelessWidget {
  final String brandName;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const DeleteConfirmDialog({
    super.key,
    required this.brandName,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Remove Item?',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Are you sure you want to remove '),
            TextSpan(
              text: '"$brandName"',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' from your cart?'),
          ],
        ),
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: const Color(0xFF6B7280),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            'Remove',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
