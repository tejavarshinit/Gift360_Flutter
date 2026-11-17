import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cosmetic bridge shown right after the Flipkart OTP confirms the SuperCoin
/// hold: "Your SuperCoins are burned — continue payment in 3…2…1".
/// Ported from React `components/SuperCoinRedeemedModal.tsx`.
class SuperCoinRedeemedModal extends StatefulWidget {
  final bool open;
  final VoidCallback onContinue;

  const SuperCoinRedeemedModal({
    super.key,
    required this.open,
    required this.onContinue,
  });

  @override
  State<SuperCoinRedeemedModal> createState() => _SuperCoinRedeemedModalState();
}

class _SuperCoinRedeemedModalState extends State<SuperCoinRedeemedModal> {
  Timer? _timer;
  int _count = 3;

  @override
  void initState() {
    super.initState();
    if (widget.open) _start();
  }

  @override
  void didUpdateWidget(covariant SuperCoinRedeemedModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _start();
    } else if (!widget.open) {
      _timer?.cancel();
    }
  }

  void _start() {
    _timer?.cancel();
    setState(() => _count = 3);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _count - 1;
      if (next <= 0) {
        t.cancel();
        widget.onContinue();
      } else {
        setState(() => _count = next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();
    final shown = _count < 1 ? 1 : _count;
    return Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.5))),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 340,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9747FF).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF9747FF).withValues(alpha: 0.12),
                                width: 6,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/SuperCOin-removebg-preview.png',
                              width: 40,
                              height: 40,
                            ),
                          ),
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34D399),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                        children: [
                          const TextSpan(text: 'Your '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Image.asset(
                                'assets/images/SuperCOin-removebg-preview.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                          ),
                          const TextSpan(text: ' SuperCoins are Burned'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Continue payment in',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(
                      height: 72,
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
                          ).createShader(bounds),
                          child: Text(
                            '$shown',
                            style: GoogleFonts.poppins(
                              fontSize: 64,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (3 - shown + 1) / 3,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFEDEAFF),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF9747FF)),
                      ),
                    ),
                  ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
