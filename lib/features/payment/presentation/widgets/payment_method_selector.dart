import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/payment/data/models/payment_method_fee.dart';

/// Radio cards for the cash payment method; each shows its platform fee in
/// rupees. Ported from React `components/PaymentMethodSelector.tsx`.
class PaymentMethodSelector extends StatelessWidget {
  final List<PaymentMethodFee> methods;
  final String value;
  final ValueChanged<String> onChange;

  /// Cash the customer pays, before the platform fee.
  final double cashAmount;
  final bool disabled;
  final bool showTotal;

  const PaymentMethodSelector({
    super.key,
    required this.methods,
    required this.value,
    required this.onChange,
    required this.cashAmount,
    this.disabled = false,
    this.showTotal = false,
  });

  static const Color _primary = Color(0xFF6C5CE7);

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty || !(cashAmount > 0)) return const SizedBox.shrink();

    final fees = methods.map((m) => computeMethodFee(m, cashAmount)).toList();
    final lowest = lowestMethodFee(methods, cashAmount);
    final activeIndex = methods.indexWhere((m) => m.code == value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CHOOSE HOW TO PAY',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < methods.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildCard(methods[i], fees[i], fees[i] == lowest && methods.length > 1),
        ],
        if (showTotal) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Total to pay',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2D2D2D)),
              ),
              const Spacer(),
              Text(
                '\u20b9${((cashAmount * 100).round() / 100 + (activeIndex >= 0 ? fees[activeIndex] : 0)).toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: _primary),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCard(PaymentMethodFee method, double fee, bool isLowest) {
    final selected = method.code == value;
    return InkWell(
      onTap: disabled ? null : () => onChange(method.code),
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _primary.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _primary : const Color(0x1A000000),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _primary : const Color(0x806B7280),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            method.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF101010),
                            ),
                          ),
                        ),
                        if (isLowest) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x2610B981),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Lowest fee',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (paymentMethodSubtext(method.code).isNotEmpty)
                      Text(
                        paymentMethodSubtext(method.code),
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+\u20b9${fee.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF101010),
                    ),
                  ),
                  Text(
                    paymentMethodFeeLabel(method),
                    style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
