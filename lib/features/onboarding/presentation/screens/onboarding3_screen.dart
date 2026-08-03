import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';
import 'package:gift360/features/onboarding/presentation/widgets/navigation_bar.dart';

class Onboarding3Screen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onStart;
  const Onboarding3Screen({super.key, required this.onBack, required this.onStart});
  @override
  State<Onboarding3Screen> createState() => _Onboarding3ScreenState();
}

class _Onboarding3ScreenState extends State<Onboarding3Screen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeUpCtrl;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _fadeUpCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))..repeat();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeUpCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeUpCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildDecorCircles(),
          Positioned(
            top: 56, left: 0, right: 0, bottom: 220,
            child: Center(
              child: AnimatedBuilder(
                animation: _fadeUpCtrl,
                builder: (context, _) => Transform.translate(
                  offset: Offset(0, 20 * (1 - _fadeUpCtrl.value)),
                  child: Opacity(
                    opacity: _fadeUpCtrl.value,
                    child: _PhoneMockup3(animCtrl: _animCtrl),
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 80, child: _buildCopyText()),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: OnboardingNavBar(
              showSkip: false, showNext: false,
              showBack: true, showGetStarted: true,
              onBack: widget.onBack, onStart: widget.onStart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorCircles() {
    final h = MediaQuery.of(context).size.height;
    return Stack(children: [
      const Positioned(top: 96, left: 8,
          child: _Circle(size: 80, color: Color(0xB3FECDD3))),
      const Positioned(top: 64, left: 80,
          child: _Circle(size: 16, color: Color(0xFFFDA4AF))),
      const Positioned(top: 160, right: 24,
          child: _Circle(size: 40, color: Color(0xFFFECDD3))),
      Positioned(bottom: h * 0.33, right: 0,
          child: const _Circle(size: 64, color: Color(0xB3FECDD3))),
      Positioned(bottom: h * 0.5, left: 48,
          child: const _Circle(size: 12, color: Color(0xFFFDA4AF))),
    ]);
  }

  Widget _buildCopyText() {
    return AnimatedBuilder(
      animation: _fadeUpCtrl,
      builder: (context, _) {
        final t = _fadeUpCtrl.value;
        return Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: Opacity(
            opacity: t,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Instant Delivery & Redeem',
                    textAlign: TextAlign.center,
                    style: OnboardingDesign.poppins(
                        fontSize: 24, fontWeight: FontWeight.w700,
                        color: OnboardingDesign.foreground)),
                const SizedBox(height: 8),
                Text(
                    'Your gift voucher arrives instantly. Redeem it online with top brands or at nearby stores \u2014 your choice.',
                    textAlign: TextAlign.center,
                    style: OnboardingDesign.poppins(
                        fontSize: 14, fontWeight: FontWeight.w400,
                        color: OnboardingDesign.mutedForeground
                    ).copyWith(height: 1.6)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

double _lerpKF(double t, List<List<double>> keys) {
  if (t <= keys[0][0]) return keys[0][1];
  for (int i = 1; i < keys.length; i++) {
    if (t <= keys[i][0]) {
      final s = (t - keys[i - 1][0]) / (keys[i][0] - keys[i - 1][0]);
      return keys[i - 1][1] + s * (keys[i][1] - keys[i - 1][1]);
    }
  }
  return keys.last[1];
}

class _PhoneMockup3 extends StatelessWidget {
  final AnimationController animCtrl;
  const _PhoneMockup3({required this.animCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 218, height: 368,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                begin: Alignment(0.3, 0), end: Alignment(1, 1),
                colors: [Color(0xFF1F2937), Color(0xFF0F172A), Color(0xFF1F2937)]),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32, offset: const Offset(0, 12))]),
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30), color: Colors.black),
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  width: 210, height: 360,
                  child: Stack(children: [
                    Positioned.fill(child: Container(
                        decoration: const BoxDecoration(gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFF1F2), Colors.white, Color(0xFFFFF7ED)])))),
                    Positioned(top: 8, left: 0, right: 0, child: Center(
                        child: Container(width: 56, height: 14,
                            decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(7))))),
                    Positioned(top: 28, left: 16, right: 16, child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('9:41', style: OnboardingDesign.poppins(
                              fontSize: 8, fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569))),
                          Text('\u25cf\u25cf\u25cf\u25cf', style: OnboardingDesign.poppins(
                              fontSize: 8, fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569).withValues(alpha: 0.7))),
                        ])),
                    Positioned(top: 52, left: 12, right: 12, child: Column(children: [
                      Text('Redeem Your Voucher', style: OnboardingDesign.poppins(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B))),
                      const SizedBox(height: 2),
                      Text('Choose how you\'d like to use it',
                          style: OnboardingDesign.poppins(
                              fontSize: 8, color: const Color(0xFF64748B))),
                    ])),
                    Positioned(top: 88, left: 0, right: 0,
                        child: Center(child: _VoucherSplitZone(animCtrl: animCtrl))),
                    Positioned(bottom: 4, left: 0, right: 0, child: Center(
                        child: Container(width: 48, height: 3,
                            decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2))))),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Positioned(right: -3, top: 48, child: Container(
            width: 3, height: 32,
            decoration: const BoxDecoration(color: Color(0xFF374151),
                borderRadius: BorderRadius.only(
                    topRight: Radius.circular(2), bottomRight: Radius.circular(2))))),
        Positioned(left: -3, top: 40, child: Container(
            width: 3, height: 20,
            decoration: const BoxDecoration(color: Color(0xFF374151),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(2), bottomLeft: Radius.circular(2))))),
        Positioned(left: -3, top: 64, child: Container(
            width: 3, height: 32,
            decoration: const BoxDecoration(color: Color(0xFF374151),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(2), bottomLeft: Radius.circular(2))))),
      ]),
    );
  }
}

class _VoucherSplitZone extends StatelessWidget {
  final AnimationController animCtrl;
  const _VoucherSplitZone({required this.animCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animCtrl,
      builder: (context, _) {
        final t = animCtrl.value;

        final mOp = _lerpKF(t, [
          [0, 1.0], [0.25, 1.0], [0.35, 0.0], [0.80, 0.0], [0.90, 1.0], [1.0, 1.0]
        ]);
        final mSc = _lerpKF(t, [
          [0, 1.0], [0.25, 1.0], [0.35, 0.92], [0.80, 0.92], [0.90, 1.0], [1.0, 1.0]
        ]);

        final oOp = _lerpKF(t, [
          [0, 0.0], [0.25, 0.0], [0.30, 1.0], [0.60, 0.95], [0.72, 0.0], [1.0, 0.0]
        ]);
        final oX = _lerpKF(t, [
          [0, 0.0], [0.30, 0.0], [0.60, -90.0], [1.0, -90.0]
        ]);
        final oY = _lerpKF(t, [
          [0, 0.0], [0.30, 0.0], [0.60, 135.0], [1.0, 135.0]
        ]);
        final oSc = _lerpKF(t, [
          [0, 1.0], [0.30, 1.0], [0.60, 0.32], [0.72, 0.12], [1.0, 0.12]
        ]);
        final oRot = _lerpKF(t, [
          [0, 0.0], [0.30, 0.0], [0.60, -14.0], [1.0, -14.0]
        ]);

        final fOp = _lerpKF(t, [
          [0, 0.0], [0.25, 0.0], [0.30, 1.0], [0.60, 0.95], [0.72, 0.0], [1.0, 0.0]
        ]);
        final fX = _lerpKF(t, [
          [0, 0.0], [0.30, 0.0], [0.60, 90.0], [1.0, 90.0]
        ]);
        final fY = _lerpKF(t, [
          [0, 0.0], [0.30, 0.0], [0.60, 135.0], [1.0, 135.0]
        ]);
        final fSc = _lerpKF(t, [
          [0, 1.0], [0.30, 1.0], [0.60, 0.32], [0.72, 0.12], [1.0, 0.12]
        ]);
        final fRot = _lerpKF(t, [
          [0, 0.0], [0.30, 0.0], [0.60, 14.0], [1.0, 14.0]
        ]);

        final gSc = _lerpKF(t, [
          [0, 1.0], [0.55, 1.0], [0.68, 1.12], [0.82, 1.0], [1.0, 1.0]
        ]);
        final gIn = _lerpKF(t, [
          [0, 0.0], [0.55, 0.0], [0.68, 1.0], [0.82, 0.0], [1.0, 0.0]
        ]);

        final trOp = _lerpKF(t, [
          [0, 0.0], [0.28, 0.0], [0.35, 1.0], [0.65, 0.0], [1.0, 0.0]
        ]);
        final trSc = _lerpKF(t, [
          [0, 0.0], [0.28, 0.0], [0.35, 1.0], [0.65, 0.4], [1.0, 0.4]
        ]);

        return SizedBox(
          width: 210, height: 320,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(bottom: 12, left: 12, right: 12,
              child: Row(children: [
                Expanded(child: Transform.scale(scale: gSc,
                    child: _ChannelCard(
                        icon: Icons.language, iconColor: const Color(0xFF3B82F6),
                        iconBg: const Color(0xFFEFF6FF),
                        border: Color.lerp(const Color(0xFFDBEAFE), const Color(0xFF93C5FD), gIn)!,
                        glow: Color.lerp(Colors.transparent, const Color(0x733B82F6), gIn)!,
                        glowRadius: gIn * 10,
                        label: 'Redeem Online', sub: 'Amazon, Myntra\u2026'))),
                const SizedBox(width: 8),
                Expanded(child: Transform.scale(scale: gSc,
                    child: _ChannelCard(
                        icon: Icons.store, iconColor: const Color(0xFFF43F5E),
                        iconBg: const Color(0xFFFFF1F2),
                        border: Color.lerp(const Color(0xFFFCE7F3), const Color(0xFFFDA4AF), gIn)!,
                        glow: Color.lerp(Colors.transparent, const Color(0x73F43F5E), gIn)!,
                        glowRadius: gIn * 10,
                        label: 'In-Store', sub: 'Nearby outlets'))),
              ]),
            ),
            _trailDot(x: oX * 0.7, y: oY * 0.7, sc: trSc, op: trOp * 0.8,
                color: const Color(0xFF60A5FA), glow: const Color(0xB33B82F6)),
            _trailDot(x: fX * 0.7, y: fY * 0.7, sc: trSc, op: trOp * 0.8,
                color: const Color(0xFFFB7185), glow: const Color(0xB3F43F5E)),
            Positioned(top: 30, left: 0, right: 0,
                child: Center(child: Transform.scale(scale: mSc,
                    child: Opacity(opacity: mOp,
                        child: const _VoucherCard(showPill: true))))),
            Positioned(top: 30, left: 0, right: 0,
                child: Center(
                    child: Transform.translate(
                        offset: Offset(oX, oY),
                        child: Transform.scale(
                            scale: oSc,
                            child: Transform.rotate(
                                angle: oRot * pi / 180,
                                child: Opacity(
                                    opacity: oOp,
                                    child: const _VoucherCard(
                                        showPill: false,
                                        ringColor: Color(0xFF93C5FD)))))))),
            Positioned(top: 30, left: 0, right: 0,
                child: Center(
                    child: Transform.translate(
                        offset: Offset(fX, fY),
                        child: Transform.scale(
                            scale: fSc,
                            child: Transform.rotate(
                                angle: fRot * pi / 180,
                                child: Opacity(
                                    opacity: fOp,
                                    child: const _VoucherCard(
                                        showPill: false,
                                        ringColor: Color(0xFFF9A8D4)))))))),
          ]),
        );
      },
    );
  }

  Widget _trailDot({
    required double x, required double y,
    required double sc, required double op,
    required Color color, required Color glow,
  }) {
    return Positioned(top: 50, left: 0, right: 0,
        child: Center(
            child: Transform.translate(
                offset: Offset(x, y),
                child: Transform.scale(
                    scale: sc,
                    child: Opacity(
                        opacity: op,
                        child: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: color,
                                boxShadow: [BoxShadow(
                                    color: glow, blurRadius: 10)])))))));
  }
}

class _VoucherCard extends StatelessWidget {
  final bool showPill;
  final Color? ringColor;
  const _VoucherCard({required this.showPill, this.ringColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170, height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: ringColor != null ? Border.all(color: ringColor!, width: 2) : null,
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: Image.asset(
            'assets/images/voucher-revealed.png', fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: LinearGradient(
                    begin: Alignment(-1, -1), end: Alignment(1, 1),
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)])),
                child: Center(child: Text('Voucher', style: OnboardingDesign.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))))),
        if (showPill)
          Positioned(bottom: 6, left: 0, right: 0, child: Center(
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4)]),
                  child: Text('Use Online or In-Store',
                      style: OnboardingDesign.poppins(
                          fontSize: 7, fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155)))))),
      ]),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg, border, glow;
  final double glowRadius;
  final String label, sub;

  const _ChannelCard({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.border, required this.glow, required this.glowRadius,
    required this.label, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(
            color: glow, blurRadius: 10, spreadRadius: glowRadius)],
      ),
      child: Column(children: [
        Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(height: 4),
        Text(label, style: OnboardingDesign.poppins(
            fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
        Text(sub, style: OnboardingDesign.poppins(
            fontSize: 7, color: const Color(0xFF64748B))),
      ]),
    );
  }
}
