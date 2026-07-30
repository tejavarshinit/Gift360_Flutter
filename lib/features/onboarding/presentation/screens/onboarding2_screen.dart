import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';
import 'package:gift360/features/onboarding/presentation/widgets/page_indicator.dart';
import 'package:gift360/features/onboarding/presentation/widgets/navigation_bar.dart';

class Onboarding2Screen extends StatefulWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const Onboarding2Screen({super.key, required this.onSkip, required this.onNext});

  @override
  State<Onboarding2Screen> createState() => _Onboarding2ScreenState();
}

class _Onboarding2ScreenState extends State<Onboarding2Screen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeUpCtrl;
  late final AnimationController _scratchCtrl;
  late final List<AnimationController> _sparkleCtrls;

  @override
  void initState() {
    super.initState();
    _fadeUpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scratchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
    _sparkleCtrls = [
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(),
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(),
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(),
    ];

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeUpCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeUpCtrl.dispose();
    _scratchCtrl.dispose();
    for (final c in _sparkleCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _decorativeCircles(),
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            bottom: 220,
            child: _heroStage(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 156,
            child: const PageIndicator(pageCount: 3, activeIndex: 1),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: _copyText(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: OnboardingNavBar(
              onSkip: widget.onSkip,
              onNext: widget.onNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircles() {
    final h = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        const Positioned(top: 96, right: 0,
            child: _Circle(size: 80, color: Color(0x99FED7AA))),
        const Positioned(top: 176, right: 48,
            child: _Circle(size: 12, color: Color(0xFFFDBA74))),
        const Positioned(top: 288, left: 12,
            child: _Circle(size: 12, color: Color(0xFFFCD34D))),
        Positioned(
          bottom: h * 0.33, left: 0,
          child: const _Circle(size: 80, color: Color(0x99FDE68A)),
        ),
      ],
    );
  }

  Widget _heroStage() {
    return Center(
      child: SizedBox(
        width: 340,
        height: 440,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 288,
              height: 288,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFFBEB),
              ),
            ),
            _PhoneMockup(scratchCtrl: _scratchCtrl),
            _FloatingSparkle(
              ctrl: _sparkleCtrls[0], top: 48, left: 40,
              size: 20, color: const Color(0xFFFBBF24), delayS: 0,
            ),
            _FloatingSparkle(
              ctrl: _sparkleCtrls[1], bottom: 40, right: 32,
              size: 16, color: const Color(0xFFFB923C), delayS: 0.8,
            ),
            _FloatingSparkle(
              ctrl: _sparkleCtrls[2], top: 200, right: 24,
              size: 16, color: const Color(0xFFFCD34D), delayS: 1.6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyText() {
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Buy in Seconds',
                    textAlign: TextAlign.center,
                    style: OnboardingDesign.poppins(
                      fontSize: 24, fontWeight: FontWeight.w700,
                      color: OnboardingDesign.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get a smooth and secure buying experience with instant voucher purchases. Just scratch to reveal your gift card details — anytime, anywhere.',
                    textAlign: TextAlign.center,
                    style: OnboardingDesign.poppins(
                      fontSize: 14, fontWeight: FontWeight.w400,
                      color: OnboardingDesign.mutedForeground,
                    ).copyWith(height: 1.6),
                  ),
                ],
              ),
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
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final AnimationController scratchCtrl;
  const _PhoneMockup({required this.scratchCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 208,
      height: 348,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment(0.3, 0),
                  end: Alignment(1, 1),
                  colors: [Color(0xFF1F2937), Color(0xFF0F172A), Color(0xFF1F2937)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.black,
                ),
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    width: 200,
                    height: 340,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFFF7ED),
                                  Colors.white,
                                  Color(0xFFFFF7ED),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              width: 56, height: 14,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 28, left: 16, right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('9:41', style: OnboardingDesign.poppins(
                                fontSize: 8, fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              )),
                              Text('\u25cf\u25cf\u25cf\u25cf', style: OnboardingDesign.poppins(
                                fontSize: 8, fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569).withValues(alpha: 0.7),
                              )),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 52, left: 12, right: 12,
                          child: Column(
                            children: [
                              Text('Voucher Purchased', style: OnboardingDesign.poppins(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              )),
                              const SizedBox(height: 2),
                              Text('Order #32198 \u00b7 Success', style: OnboardingDesign.poppins(
                                fontSize: 8, fontWeight: FontWeight.w500,
                                color: const Color(0xFF059669),
                              )),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 88, left: 0, right: 0,
                          child: Center(
                            child: _VoucherStack(scratchCtrl: scratchCtrl),
                          ),
                        ),
                        Positioned(
                          top: 218, left: 0, right: 0,
                          child: Text(
                            'Scratch to reveal your card',
                            textAlign: TextAlign.center,
                            style: OnboardingDesign.poppins(
                              fontSize: 8, fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16, left: 16, right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment(-1, -0.5),
                                end: Alignment(1, 0.5),
                                colors: [Color(0xFFFF8A3D), Color(0xFFFF5A1F)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33FF8A3D),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'View Voucher',
                              textAlign: TextAlign.center,
                              style: OnboardingDesign.poppins(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              width: 48, height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -3, top: 48,
            child: Container(
              width: 3, height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF374151),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
          Positioned(
            left: -3, top: 40,
            child: Container(
              width: 3, height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFF374151),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
              ),
            ),
          ),
          Positioned(
            left: -3, top: 64,
            child: Container(
              width: 3, height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF374151),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherStack extends StatelessWidget {
  final AnimationController scratchCtrl;
  const _VoucherStack({required this.scratchCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(-7 * pi / 180)
              ..translate(0.0, 8.0),
            child: Opacity(
              opacity: 0.55,
              child: Container(
                width: 160, height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment(-1, -1),
                    end: Alignment(1, 1),
                    colors: [Color(0xFFFFD089), Color(0xFFFF8A3D)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(4 * pi / 180)
              ..translate(0.0, 4.0),
            child: Opacity(
              opacity: 0.75,
              child: Container(
                width: 164, height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment(-1, -1),
                    end: Alignment(1, 1),
                    colors: [Color(0xFFFFC066), Color(0xFFFF7A25)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: scratchCtrl,
            builder: (context, _) {
              final t = scratchCtrl.value;

              double rightEdge;
              if (t < 0.18) {
                rightEdge = 1.0;
              } else {
                final wipeProgress = ((t - 0.18) / 0.71).clamp(0.0, 1.0);
                rightEdge = 1.0 - wipeProgress;
              }

              double fingerX;
              double fingerOpacity;
              if (t < 0.08) {
                fingerX = 0.88;
                fingerOpacity = 0.0;
              } else if (t < 0.15) {
                fingerX = 0.88;
                fingerOpacity = (t - 0.08) / 0.07;
              } else if (t < 0.55) {
                fingerX = 0.88;
                fingerOpacity = 1.0;
              } else if (t < 0.85) {
                final moveProgress = ((t - 0.55) / 0.30).clamp(0.0, 1.0);
                fingerX = 0.88 - moveProgress * 0.80;
                fingerOpacity = 1.0;
              } else if (t < 0.90) {
                fingerX = 0.08;
                fingerOpacity = (0.90 - t) / 0.05;
              } else {
                fingerX = 0.08;
                fingerOpacity = 0.0;
              }

              double popScale = 1.0;
              if (t >= 0.80 && t < 0.85) {
                popScale = 1.0 + 0.04 * ((t - 0.80) / 0.05);
              } else if (t >= 0.85 && t < 0.92) {
                popScale = 1.04 - 0.04 * ((t - 0.85) / 0.07);
              }

              return Transform.scale(
                scale: popScale,
                child: SizedBox(
                  width: 170,
                  height: 118,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/images/voucher-revealed.png',
                            width: 170, height: 118,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment(-1, -1),
                                  end: Alignment(1, 1),
                                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text('Voucher', style: OnboardingDesign.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipPath(
                          clipper: _ScratchClipper(rightEdge: rightEdge),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/images/voucher-cover.png',
                              width: 170, height: 118,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment(-1, -1),
                                    end: Alignment(1, 1),
                                    colors: [Color(0xFFFFC066), Color(0xFFFF7A25)],
                                  ),
                                ),
                                child: Center(
                                  child: Text('Scratch Me', style: OnboardingDesign.poppins(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  )),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 49,
                        left: fingerX * 170 - 10,
                        child: Opacity(
                          opacity: fingerOpacity,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xE6FFFFFF),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScratchClipper extends CustomClipper<Path> {
  final double rightEdge;

  _ScratchClipper({required this.rightEdge});

  @override
  Path getClip(Size size) {
    final x = size.width * rightEdge;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(x, 0)
      ..lineTo(x, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_ScratchClipper old) => old.rightEdge != rightEdge;
}

class _FloatingSparkle extends StatelessWidget {
  final AnimationController ctrl;
  final double? top, bottom, left, right;
  final double size;
  final Color color;
  final double delayS;

  const _FloatingSparkle({
    required this.ctrl,
    this.top, this.bottom, this.left, this.right,
    required this.size,
    required this.color,
    required this.delayS,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          final adjusted = (ctrl.value + delayS / 2.6) % 1.0;
          final sine = sin(adjusted * 2 * pi);
          final opacity = (sine + 1) / 2;
          final scale = 0.6 + opacity * 0.6;
          final rotation = adjusted * pi;
          return Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: opacity,
                child: Icon(Icons.auto_awesome, color: color, size: size),
              ),
            ),
          );
        },
      ),
    );
  }
}
