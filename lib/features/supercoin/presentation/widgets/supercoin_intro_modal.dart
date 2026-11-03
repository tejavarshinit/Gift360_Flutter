import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/features/supercoin/presentation/widgets/supercoin_guide_sheet.dart';

/// Port of React `src/components/SuperCoinIntroModal.tsx`.
///
/// First-time modal shown after login/register (flag `showSuperCoinIntro`).
/// Hosts a master pill toggle ("for all brands" / "for SuperCoins voucher"),
/// the SuperCoinBanner (which opens the guide sheet) and the convert steps
/// whose "Try Now" CTA navigates to `/supercoin-voucher`.
class SuperCoinIntroModal extends StatefulWidget {
  final bool open;
  final VoidCallback onClose;

  /// 'brands' | 'convert' — React's `initialTab` (the home banner's
  /// "View guide" CTA opens straight on the convert steps).
  final String? initialTab;

  const SuperCoinIntroModal({
    super.key,
    required this.open,
    required this.onClose,
    this.initialTab,
  });

  @override
  State<SuperCoinIntroModal> createState() => _SuperCoinIntroModalState();
}

class _SuperCoinIntroModalState extends State<SuperCoinIntroModal> {
  static const String _coinImg = 'assets/images/SuperCOin-removebg-preview.png';

  /// "brands" | "convert"
  String _tab = 'brands';
  bool _guideOpen = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ?? 'brands';
  }

  @override
  void didUpdateWidget(covariant SuperCoinIntroModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      setState(() {
        _tab = widget.initialTab ?? 'brands';
        _guideOpen = false;
      });
    }
  }

  void _goTryNow() {
    final router = GoRouter.of(context);
    widget.onClose();
    // Defer navigation to next frame so the modal's state update settles
    // first (mirrors React: onClose() then setLocation()).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go('/supercoin-voucher');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Backdrop (z-90): bg-black/50 + blur(6px), tap closes
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
        ),
        // Dialog (z-100)
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  // w-[min(92vw,380px)]
                  constraints: BoxConstraints(maxWidth: (size.width * 0.92).clamp(0.0, 380.0)),
                  child: _buildCard(context, size),
                ),
              ),
            ),
          ),
        ),
        if (_guideOpen)
          SuperCoinGuideSheet(
            open: _guideOpen,
            onClose: () => setState(() => _guideOpen = false),
          ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, Size size) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x5916162C), blurRadius: 60, offset: Offset(0, 24)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          _buildTabs(),
          // max-h-[60vh] overflow-y-auto px-4 py-3
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height * 0.6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SingleChildScrollView(
                child: _tab == 'brands' ? _buildBrandsTab() : _buildConvertTab(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9747FF), Color(0xFF7C3AED), Color(0xFF5B2B99)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Image.asset(_coinImg, width: 32, height: 32, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SuperCoins, made simple',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Two ways to put your coins to work',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Master pill toggle — React `TABS` (flex gap-2 px-4 pt-3).
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(child: _tabButton('brands', 'for all brands')),
          const SizedBox(width: 8),
          Expanded(child: _tabButton('convert', 'for SuperCoins voucher')),
        ],
      ),
    );
  }

  Widget _tabButton(String id, String label) {
    final active = _tab == id;
    return GestureDetector(
      onTap: () => setState(() => _tab = id),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C3AED) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: const Color(0xFFE2D9FF)),
          boxShadow: active
              ? const [BoxShadow(color: Color(0x4D7C3AED), blurRadius: 12, offset: Offset(0, 4))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }

  // ── Tab 1: "for all brands" ──
  Widget _buildBrandsTab() {
    return Column(
      children: [
        SuperCoinBanner(onOpenGuide: () => setState(() => _guideOpen = true)),
        const SizedBox(height: 8),
        Text(
          'Tap the card for the step-by-step walkthrough.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ── Tab 2: "for SuperCoins voucher" — convert steps + Try Now ──
  Widget _buildConvertTab() {
    const steps = <_ConvertStep>[
      _ConvertStep(
        icon: Icons.touch_app_outlined,
        title: 'Tap "Try Now"',
        text: 'Open the SuperCoin E-Gift Voucher from the Try Now entry on the home screen.',
      ),
      _ConvertStep(
        icon: Icons.savings_outlined,
        title: 'Tap "Convert your SuperCoins"',
        text: 'Pick an amount and hit Convert — your available SuperCoin balance shows right there.',
      ),
      _ConvertStep(
        icon: Icons.verified_outlined,
        title: 'Enter OTP & done',
        text:
            'Approve with the OTP. Coins convert instantly and your SuperCoin Voucher lands in My Orders.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildStepCard(steps[i], i + 1),
        ],
        const SizedBox(height: 8),
        _buildTryNowButton(),
      ],
    );
  }

  Widget _buildStepCard(_ConvertStep step, int number) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFAF5FF)),
        boxShadow: const [BoxShadow(color: Color(0x147C3AED), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F1FE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.icon, size: 20, color: const Color(0xFF7C3AED)),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
                    child: Text(
                      '$number',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF151722),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.text,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTryNowButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _goTryNow,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF9747FF), Color(0xFF5B2B99)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x4D9747FF), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(_coinImg, width: 16, height: 16, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Text(
                'Try Now',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConvertStep {
  final IconData icon;
  final String title;
  final String text;
  const _ConvertStep({required this.icon, required this.title, required this.text});
}

/// Port of React `src/components/SuperCoinBanner.tsx` — the animated gradient
/// card inside the intro modal's "for all brands" tab.
class SuperCoinBanner extends StatefulWidget {
  final VoidCallback onOpenGuide;
  const SuperCoinBanner({super.key, required this.onOpenGuide});

  @override
  State<SuperCoinBanner> createState() => _SuperCoinBannerState();
}

class _SuperCoinBannerState extends State<SuperCoinBanner> with TickerProviderStateMixin {
  static const String _coinImg = 'assets/images/SuperCOin-removebg-preview.png';

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat(reverse: true);
  late final AnimationController _tilt = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2250),
  )..repeat(reverse: true);
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  )..repeat();
  late final AnimationController _chip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat(reverse: true);
  late final AnimationController _arrow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _float.dispose();
    _tilt.dispose();
    _shimmer.dispose();
    _chip.dispose();
    _arrow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenGuide,
      child: AnimatedBuilder(
        animation: Listenable.merge([_float, _tilt, _shimmer, _chip, _arrow]),
        builder: (context, _) {
          final floatY = _reduceMotion ? 0.0 : Tween<double>(begin: 0, end: -6).animate(
            CurvedAnimation(parent: _float, curve: Curves.easeInOut),
          ).value;
          final tiltDeg = _reduceMotion ? -8.0 : Tween<double>(begin: -8, end: 8).animate(
            CurvedAnimation(parent: _tilt, curve: Curves.easeInOut),
          ).value;
          final shimmerT = _reduceMotion ? 1.0 : _shimmer.value;
          final chipScale = _reduceMotion ? 1.0 : Tween<double>(begin: 1, end: 1.05).animate(
            CurvedAnimation(parent: _chip, curve: Curves.easeInOut),
          ).value;
          final arrowX = _reduceMotion ? 0.0 : Tween<double>(begin: 0, end: 4).animate(
            CurvedAnimation(parent: _arrow, curve: Curves.easeInOut),
          ).value;

          return Container(
            height: 185,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF5365DF)],
                stops: [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Decorative glows
                Positioned(
                  top: -32, left: -24,
                  child: _glow(112),
                ),
                Positioned(
                  bottom: -40, right: 32,
                  child: _glow(96),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
                  child: Row(
                    children: [
                      Expanded(child: _leftColumn(arrowX, chipScale)),
                      _coinColumn(floatY, tiltDeg, shimmerT),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _glow(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.10), blurRadius: 40)],
      ),
    );
  }

  Widget _leftColumn(double arrowX, double chipScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // NEW ✨ SuperCoins chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'NEW ✨ SuperCoins',
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'How to use SuperCoins',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        // "Convert SC to instant savings" pulsing chip
        Transform.scale(
          scale: chipScale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(_coinImg, width: 11, height: 11, fit: BoxFit.contain),
                const SizedBox(width: 4),
                Text(
                  'Convert SC to instant savings',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6D28D9),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'See how it works',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Transform.translate(
              offset: Offset(arrowX, 0),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: const Text('→', style: TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _coinColumn(double floatY, double tiltDeg, double shimmerT) {
    return SizedBox(
      width: 112,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Sparkles
          Positioned(top: 16, left: 8, child: _twinkle(5, 0.2)),
          Positioned(bottom: 24, left: 16, child: _twinkle(4, 1.1)),
          Positioned(top: 32, right: 8, child: _twinkle(6, 1.7)),
          Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.rotate(
              angle: tiltDeg * 3.141592653589793 / 180,
              child: SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(_coinImg, width: 92, height: 92, fit: BoxFit.contain),
                    // Shimmer sweep
                    if (!_reduceMotion)
                      Positioned.fill(
                        child: ClipOval(
                          child: Transform.translate(
                            offset: Offset(-140 + shimmerT * 400, 0),
                            child: Container(
                              width: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _twinkle(double size, double delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.15, end: 1.0),
      duration: const Duration(milliseconds: 2200),
      builder: (context, v, child) {
        final phase = (v + delay) % 2.0;
        final opacity = phase < 1.0 ? phase : 2.0 - phase;
        return Opacity(opacity: _reduceMotion ? 0.4 : opacity, child: child!);
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}
