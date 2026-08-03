import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';
import 'package:gift360/features/onboarding/presentation/widgets/navigation_bar.dart';

class _BrandDef {
  final String? asset;
  final String? label;
  final Color bg;
  final Color color;
  final double fontSize;
  final FontWeight weight;
  final bool italic;

  const _BrandDef({
    this.asset,
    this.label,
    required this.bg,
    required this.color,
    this.fontSize = 8,
    this.weight = FontWeight.w800,
    this.italic = false,
  });

  static _BrandDef img(String name) => _BrandDef(
        asset: 'assets/images/pp-brands/$name.png',
        bg: Colors.transparent,
        color: Colors.transparent,
      );

  static _BrandDef txt(String label, String bgHex, String colorHex,
          {double fontSize = 8, FontWeight weight = FontWeight.w800, bool italic = false}) =>
      _BrandDef(
        label: label,
        bg: _hex(bgHex),
        color: _hex(colorHex),
        fontSize: fontSize,
        weight: weight,
        italic: italic,
      );

  static Color _hex(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));
}

final _row1 = [
  _BrandDef.img('amazon'),
  _BrandDef.txt("Domino's", '#006491', '#ffffff', fontSize: 7, italic: true),
  _BrandDef.txt('Trends', '#E63946', '#ffffff', fontSize: 8),
  _BrandDef.txt('M', '#FFC72C', '#DA291C', fontSize: 20, weight: FontWeight.w900),
  _BrandDef.img('puma'),
];

final _row2 = [
  _BrandDef.img('flipkart'),
  _BrandDef.txt('Zepto', '#7B3FE4', '#FFE249', fontSize: 9),
  _BrandDef.txt('Westside', '#0E0E0E', '#ffffff', fontSize: 7),
  _BrandDef.txt('KFC', '#E4002B', '#ffffff', fontSize: 9),
  _BrandDef.txt('Starbucks', '#006241', '#ffffff', fontSize: 6),
];

final _row3 = [
  _BrandDef.img('myntra'),
  _BrandDef.txt('blinkit', '#F8CB46', '#1A1A1A', fontSize: 9),
  _BrandDef.txt('BMS', '#C8102E', '#ffffff', fontSize: 10),
  _BrandDef.txt('Decathlon', '#0082C3', '#ffffff', fontSize: 6),
  _BrandDef.txt('bigbasket', '#84C225', '#ffffff', fontSize: 6),
];

class _CharDef {
  final String asset;
  final double size;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final Color ringColor;
  final int delayMs;

  const _CharDef({
    required this.asset,
    required this.size,
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.ringColor,
    this.delayMs = 0,
  });
}

const _chars = [
  _CharDef(asset: 'onboard-collegegirl.png', size: 70, left: 8, top: 48,
      ringColor: Color(0x73F472B6)),
  _CharDef(asset: 'onboard-couple.png', size: 62, left: 96, top: 4,
      ringColor: Color(0x66F43E5E), delayMs: 100),
  _CharDef(asset: 'onboard-senior.png', size: 66, right: 8, top: 12,
      ringColor: Color(0x80A78BFA), delayMs: 200),
  _CharDef(asset: 'onboard-housewife.png', size: 74, left: 4, bottom: 24,
      ringColor: Color(0x802DD4BF), delayMs: 100),
  _CharDef(asset: 'onboard-shopkeeper.png', size: 62, left: 96, bottom: 0,
      ringColor: Color(0x80FBBF24), delayMs: 300),
  _CharDef(asset: 'onboard-gigworker.png', size: 66, right: 8, bottom: 8,
      ringColor: Color(0x8CFB923C), delayMs: 400),
  _CharDef(asset: 'onboard-businessman.png', size: 68, right: 4, bottom: 96,
      ringColor: Color(0x8064748B), delayMs: 200),
  _CharDef(asset: 'onboard-itemployee.png', size: 60, left: 4, top: 144,
      ringColor: Color(0x803B82F6), delayMs: 300),
  _CharDef(asset: 'onboard-student.png', size: 56, right: 8, top: 128,
      ringColor: Color(0x8C38BDF8), delayMs: 400),
];

class Onboarding1Screen extends StatefulWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const Onboarding1Screen({super.key, required this.onSkip, required this.onNext});

  @override
  State<Onboarding1Screen> createState() => _Onboarding1ScreenState();
}

class _Onboarding1ScreenState extends State<Onboarding1Screen>
    with TickerProviderStateMixin {
  late final AnimationController _phoneScaleCtrl;
  late final AnimationController _fadeUpCtrl;
  late final List<AnimationController> _marqueeCtrls;

  @override
  void initState() {
    super.initState();
    _phoneScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeUpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _marqueeCtrls = [
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(),
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(),
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(),
    ];

    _phoneScaleCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeUpCtrl.forward();
    });
  }

  @override
  void dispose() {
    _phoneScaleCtrl.dispose();
    _fadeUpCtrl.dispose();
    for (final c in _marqueeCtrls) c.dispose();
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
            bottom: 200,
            child: _heroStage(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
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
        const Positioned(
          top: 80, right: 0,
          child: _Circle(size: 80, color: Color(0xB3BAE6FD)),
        ),
        const Positioned(
          top: 128, left: 24,
          child: _Circle(size: 12, color: Color(0xFF7DD3FC)),
        ),
        const Positioned(
          top: 48, left: 64,
          child: _Circle(size: 8, color: Color(0xFF7DD3FC)),
        ),
        Positioned(
          bottom: h * 0.33, left: 0,
          child: const _Circle(size: 56, color: Color(0x99BAE6FD)),
        ),
        Positioned(
          bottom: h * 0.5, right: 32,
          child: const _Circle(size: 12, color: Color(0xFF7DD3FC)),
        ),
      ],
    );
  }

  Widget _heroStage() {
    return Center(
      child: SizedBox(
        width: 320,
        height: 420,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xCCBAE6FD),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 4,
              child: _LogoTag(),
            ),
            ..._chars.map((c) => Positioned(
              left: c.left,
              right: c.right,
              top: c.top,
              bottom: c.bottom,
              child: PortraitChip(
                asset: c.asset,
                size: c.size,
                ringColor: c.ringColor,
                delayMs: c.delayMs,
              ),
            )),
            AnimatedBuilder(
              animation: _phoneScaleCtrl,
              builder: (context, child) {
                final t = _phoneScaleCtrl.value;
                return Transform.scale(
                  scale: 0.85 + t * 0.15,
                  child: Opacity(
                    opacity: t,
                    child: _PhoneMockup(marqueeCtrls: _marqueeCtrls),
                  ),
                );
              },
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
                    'Gifting for Everyone',
                    textAlign: TextAlign.center,
                    style: OnboardingDesign.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: OnboardingDesign.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From students to seniors, find the perfect voucher from 300+ top brands across shopping, food, fitness, travel and more.',
                    textAlign: TextAlign.center,
                    style: OnboardingDesign.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
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
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _LogoTag extends StatefulWidget {
  @override
  State<_LogoTag> createState() => _LogoTagState();
}

class _LogoTagState extends State<_LogoTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final yOff = sin(t * 2 * pi) * 6;
        final rot = sin(t * 2 * pi) * 2 * pi / 180;
        return Transform.translate(
          offset: Offset(0, -yOff),
          child: Transform.rotate(
            angle: rot,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
                boxShadow: OnboardingDesign.shadowTile,
              ),
              child: Image.asset(
                'assets/images/gift360-logo.png',
                height: 24,
                errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, size: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PortraitChip extends StatefulWidget {
  final String asset;
  final double size;
  final Color ringColor;
  final int delayMs;

  const PortraitChip({
    super.key,
    required this.asset,
    required this.size,
    required this.ringColor,
    this.delayMs = 0,
  });

  @override
  State<PortraitChip> createState() => _PortraitChipState();
}

class _PortraitChipState extends State<PortraitChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final yOff = sin(_ctrl.value * 2 * pi) * 10;
        return Transform.translate(
          offset: Offset(0, -yOff),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x400F172A),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
                const BoxShadow(
                  color: Colors.white,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: widget.ringColor,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/${widget.asset}',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.person, size: widget.size * 0.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final List<AnimationController> marqueeCtrls;
  const _PhoneMockup({required this.marqueeCtrls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 268,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment(0.3, 0),
                  end: Alignment(1, 1),
                  colors: [Color(0xFF1F2937), Color(0xFF0F172A), Color(0xFF1F2937)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.black,
                ),
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 148,
                    height: 260,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFF0F9FF), Colors.white, Color(0xFFF0F9FF)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 22,
                          left: 12,
                          right: 12,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('9:41', style: OnboardingDesign.poppins(
                                fontSize: 7, fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              )),
                              const Spacer(),
                              const Icon(Icons.signal_cellular_alt, size: 6, color: Color(0xFF475569)),
                              const SizedBox(width: 2),
                              const Icon(Icons.wifi, size: 6, color: Color(0xFF475569)),
                              const SizedBox(width: 2),
                              const Icon(Icons.battery_full, size: 8, color: Color(0xFF475569)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 40,
                          left: 10,
                          child: Image.asset(
                            'assets/images/gift360-logo.png',
                            height: 20,
                            errorBuilder: (_, __, ___) => Text('Gift360',
                              style: OnboardingDesign.poppins(fontSize: 8, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Positioned(
                          top: 62,
                          left: 10,
                          child: Text('300+ top brands', style: OnboardingDesign.poppins(
                            fontSize: 7, color: OnboardingDesign.mutedForeground,
                          )),
                        ),
                        Positioned(
                          top: 78,
                          left: 6,
                          right: 6,
                          bottom: 40,
                          child: Column(
                            children: [
                              _MarqueeRow(controller: marqueeCtrls[0], items: _row1, reverse: false),
                              const SizedBox(height: 6),
                              _MarqueeRow(controller: marqueeCtrls[1], items: _row2, reverse: true),
                              const SizedBox(height: 6),
                              _MarqueeRow(controller: marqueeCtrls[2], items: _row3, reverse: false),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: OnboardingDesign.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Buy a Voucher',
                              textAlign: TextAlign.center,
                              style: OnboardingDesign.poppins(
                                fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 40, height: 3,
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
            right: -3,
            top: 48,
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
            left: -3,
            top: 40,
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
            left: -3,
            top: 64,
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

class _MarqueeRow extends StatelessWidget {
  final AnimationController controller;
  final List<_BrandDef> items;
  final bool reverse;

  const _MarqueeRow({
    required this.controller,
    required this.items,
    required this.reverse,
  });

  @override
  Widget build(BuildContext context) {
    final singleWidth = items.length * (32.0 + 6.0);

    return ClipRect(
      child: SizedBox(
        height: 32,
        child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final progress = controller.value;
          final offset = reverse
              ? -singleWidth + progress * singleWidth
              : -progress * singleWidth;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: Row(
              children: [
                ...items,
                ...items,
                ...items,
              ].map((tile) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _BrandTile(tile: tile, size: 32),
                );
              }).toList(),
            ),
          );
        },
      ),
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  final _BrandDef tile;
  final double size;
  const _BrandTile({required this.tile, required this.size});

  @override
  Widget build(BuildContext context) {
    if (tile.asset != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          tile.asset!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tile.bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        tile.label!,
        style: OnboardingDesign.poppins(
          fontSize: tile.fontSize,
          fontWeight: tile.weight,
          color: tile.color,
          letterSpacing: -0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
