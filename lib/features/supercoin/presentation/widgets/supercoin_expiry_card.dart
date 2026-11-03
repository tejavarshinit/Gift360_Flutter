import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';


/// "Extend your SuperCoins' expiry" card shown in the convert modal before a
/// hold is applied. Ported from React `components/SuperCoinExpiryCard.tsx`.
class SuperCoinExpiryCard extends StatelessWidget {
  final int coinsNeeded;
  final double voucherValue;
  final bool loggedIn;
  final bool balanceLoading;
  final bool canConvert;
  final bool busy;
  final bool paused;
  final String pausedMessage;
  final VoidCallback onConvert;
  final VoidCallback onLogin;

  const SuperCoinExpiryCard({
    super.key,
    required this.coinsNeeded,
    required this.voucherValue,
    required this.loggedIn,
    required this.balanceLoading,
    required this.canConvert,
    required this.busy,
    required this.paused,
    required this.pausedMessage,
    required this.onConvert,
    required this.onLogin,
  });

  String get _label {
    if (paused) return 'Temporarily unavailable';
    if (!loggedIn) return 'Login to extend';
    if (balanceLoading) return 'Checking your balance...';
    if (!canConvert) return 'Not enough SuperCoins';
    return 'Convert & extend';
  }

  bool get _disabled => paused || balanceLoading || (!loggedIn ? false : !canConvert);

  VoidCallback get _onTap => !loggedIn ? onLogin : onConvert;

  String? get _hint {
    if (paused) return pausedMessage;
    if (loggedIn && !balanceLoading && !canConvert) {
      return 'You need ${_formatNumber(coinsNeeded)} SuperCoins for a '
          '\u20b9${_formatNumber(voucherValue)} voucher. '
          'Check your balance in the Flipkart app.';
    }
    return null;
  }

  static String _formatNumber(num value) {
    final whole = value == value.roundToDouble();
    final format = whole
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##,##0.00', 'en_IN');
    return format.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9747FF), Color(0xFF7C3AED), Color(0xFF5B2B99)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF5B2B99).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_empty, size: 16, color: Color(0xFFF7D46B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Extend your SuperCoins' expiry by 6 months",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Convert them into a voucher, then redeem it for fresh SuperCoins.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 14, height: 14),
                const SizedBox(width: 6),
                Text('${_formatNumber(coinsNeeded)} coins',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(' \u2192 ', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                Text('\u20b9${_formatNumber(voucherValue)} voucher',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _disabled || busy ? null : _onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5B2B99),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
                disabledForegroundColor: const Color(0xFF5B2B99),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B2B99)))
                  : Text(_label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          if (_hint != null) ...[
            const SizedBox(height: 6),
            Text(
              _hint!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}
