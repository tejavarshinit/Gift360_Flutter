import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InstantGiftingCarousel extends StatefulWidget {
  final VoidCallback? onExploreBrands;
  const InstantGiftingCarousel({super.key, this.onExploreBrands});

  @override
  State<InstantGiftingCarousel> createState() => _InstantGiftingCarouselState();
}

class _InstantGiftingCarouselState extends State<InstantGiftingCarousel>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  Timer? _autoTimer;
  bool _userInteracting = false;
  int _currentPage = 0;

  static const _accent = Color(0xFF7C3AED);
  static const _duration = Duration(milliseconds: 450);
  static const _autoInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAuto() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoInterval, (_) {
      if (_userInteracting || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % 3;
      _pageController.animateToPage(next, duration: _duration, curve: Curves.easeInOut);
    });
  }

  void _onUserInteract() {
    _userInteracting = true;
    _autoTimer?.cancel();
  }

  void _onUserRelease() {
    _userInteracting = false;
    _startAuto();
  }

  void _jumpTo(int index) {
    _pageController.animateToPage(index, duration: _duration, curve: Curves.easeInOut);
    _onUserInteract();
    Future.delayed(const Duration(seconds: 4), _onUserRelease);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 400;
        final padding = isMobile
            ? const EdgeInsets.fromLTRB(16, 16, 16, 16)
            : const EdgeInsets.fromLTRB(40, 32, 40, 32);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onPanDown: (_) => _onUserInteract(),
              onPanEnd: (_) => _onUserRelease(),
              onTapDown: (_) => _onUserInteract(),
              onTapUp: (_) => _onUserRelease(),
              child: Container(
                height: isMobile ? 200 : 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), offset: Offset(4, 4), blurRadius: 4),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildSlide1(padding, isMobile),
                      _buildSlide2(padding, isMobile),
                      _buildSlide3(padding, isMobile),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildDots(),
          ],
        );
      },
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = _currentPage == i;
        return GestureDetector(
          onTap: () => _jumpTo(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? _accent : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  // ─── Slide 1: Step Flow ───
  Widget _buildSlide1(EdgeInsets padding, bool isMobile) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge('INSTANT GIFTING', Colors.grey[400]!),
          const SizedBox(height: 8),
          Text(
            'Pick a brand, buy a voucher, send it in seconds',
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          _buildCTA(label: 'Start gifting', bg: const Color(0xFF1F2937), onTap: widget.onExploreBrands),
          const SizedBox(height: 10),
          _buildStepsRow(isMobile),
        ],
      ),
    );
  }

  Widget _buildStepsRow(bool isMobile) {
    final steps = [
      (Icons.store_outlined, 'Pick a brand', 'From 500+ options'),
      (Icons.shopping_cart_outlined, 'Buy instantly', 'UPI, cards, wallet'),
      (Icons.card_giftcard, 'Send instantly', 'Straight to their phone'),
    ];

    final circleSize = isMobile ? 36.0 : 40.0;
    final iconSize = isMobile ? 16.0 : 18.0;
    final titleSize = isMobile ? 11.0 : 13.0;
    final descSize = isMobile ? 9.0 : 11.0;
    final stepLabelSize = isMobile ? 8.0 : 10.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        final s = steps[i];
        return [
          if (i > 0)
            Expanded(
              flex: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Container(
                  height: 2,
                  width: 8,
                  color: const Color(0xFFEDE9FE),
                ),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: const BoxDecoration(color: Color(0xFFF3F0FF), shape: BoxShape.circle),
                  child: Icon(s.$1, color: _accent, size: iconSize),
                ),
                const SizedBox(height: 3),
                Text(
                  'Step ${i + 1}',
                  style: TextStyle(fontSize: stepLabelSize, letterSpacing: 0.05, color: Colors.grey[400]),
                ),
                const SizedBox(height: 1),
                Text(
                  s.$2,
                  style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.grey[900]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 1),
                  Text(
                    s.$3,
                    style: TextStyle(fontSize: descSize, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ];
      }).expand((e) => e).toList(),
    );
  }

  // ─── Slide 2: SuperCoins ───
  Widget _buildSlide2(EdgeInsets padding, bool isMobile) {
    return Padding(
      padding: padding,
      child: isMobile
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAccentBadge('REWARDS'),
                      const SizedBox(height: 6),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827), height: 1.3),
                          children: [
                            TextSpan(text: 'Earn '),
                            TextSpan(text: 'SuperCoins', style: TextStyle(color: Color(0xFF7C3AED))),
                            TextSpan(text: ' on every purchase'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get rewarded every time you buy or send a gift voucher.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _buildCTA(label: 'Explore Now', bg: _accent, onTap: widget.onExploreBrands),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 90,
                  height: 90,
                  child: _buildSuperCoinIllustration(small: true),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAccentBadge('REWARDS'),
                      const SizedBox(height: 10),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827), height: 1.3),
                          children: [
                            TextSpan(text: 'Earn '),
                            TextSpan(text: 'SuperCoins', style: TextStyle(color: Color(0xFF7C3AED))),
                            TextSpan(text: ' on every purchase'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Get rewarded every time you buy or send a gift voucher.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _buildCTA(label: 'Explore Now', bg: _accent, onTap: widget.onExploreBrands),
                          const SizedBox(width: 12),
                          _buildSuperCoinInfo(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _buildSuperCoinIllustration()),
              ],
            ),
    );
  }

  Widget _buildSuperCoinInfo() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: Color(0xFFF3F0FF), shape: BoxShape.circle),
          child: const Icon(Icons.monetization_on_outlined, color: _accent, size: 20),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SuperCoins', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[900])),
            Text('Redeem across 500+ brands on Gift360', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _buildSuperCoinIllustration({bool small = false}) {
    final imgWidth = small ? 70.0 : 160.0;
    final coinCount = small ? 6 : 12;
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/FlipKartSuperCoin-removebg-preview.png',
          width: imgWidth,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.monetization_on, size: small ? 40 : 80, color: const Color(0xFFFFC800)),
        ),
        ...List.generate(coinCount, (i) {
          final rng = Random(i);
          final size = (small ? 8.0 : 14.0) + rng.nextDouble() * (small ? 6 : 10);
          final left = -(small ? 25.0 : 40.0) + rng.nextDouble() * (small ? 50 : 80);
          final top = -(small ? 35.0 : 60.0) + rng.nextDouble() * (small ? 70 : 120);
          final delay = rng.nextDouble() * 1.8;
          final dur = 2.5 + rng.nextDouble() * 0.7;
          return _FloatingCoin(key: ValueKey(i), size: size, left: left, top: top, delay: delay, duration: dur);
        }),
      ],
    );
  }

  // ─── Slide 3: Partner ───
  Widget _buildSlide3(EdgeInsets padding, bool isMobile) {
    return Padding(
      padding: padding,
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAccentBadge('PARTNER'),
                const SizedBox(height: 8),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827), height: 1.3),
                    children: [
                      TextSpan(text: 'Unlock '),
                      TextSpan(text: 'bulk pricing', style: TextStyle(color: Color(0xFF7C3AED))),
                      TextSpan(text: ' as a partner'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bulk pricing, smart reselling, and corporate gifting — all in one place.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                _buildCTA(
                  label: 'Partner With Us',
                  bg: _accent,
                  onTap: () => launchUrl(Uri.parse('http://localhost:7789/distributor'), mode: LaunchMode.externalApplication),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAccentBadge('PARTNER'),
                      const SizedBox(height: 10),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827), height: 1.3),
                          children: [
                            TextSpan(text: 'Unlock '),
                            TextSpan(text: 'bulk pricing', style: TextStyle(color: Color(0xFF7C3AED))),
                            TextSpan(text: ' as a partner'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bulk pricing, smart reselling, and corporate gifting — all in one place.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                      const Spacer(),
                      _buildCTA(
                        label: 'Partner With Us',
                        bg: _accent,
                        onTap: () => launchUrl(Uri.parse('http://localhost:7789/distributor'), mode: LaunchMode.externalApplication),
                      ),
                      const SizedBox(height: 10),
                      _buildPartnerChips(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _buildPartnerIllustration()),
              ],
            ),
    );
  }

  Widget _buildPartnerChips() {
    final chips = [
      (Icons.attach_money, 'Bulk Pricing'),
      (Icons.refresh, 'Smart Reselling'),
      (Icons.card_giftcard, 'Corporate Gifting'),
    ];
    return Row(
      children: chips.map((c) {
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Color(0xFFF3F0FF), shape: BoxShape.circle),
                child: Icon(c.$1, color: _accent, size: 16),
              ),
              const SizedBox(height: 3),
              Text(
                c.$2,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPartnerIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 100,
          height: 65,
          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              Positioned(
                top: 18,
                left: 38,
                child: Container(
                  width: 24,
                  height: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFC4B5FD), width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 18,
          child: Container(
            width: 30,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: _accent, width: 3),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
          ),
        ),
        Positioned(top: 15, left: 0, child: _buildMiniGift(30, 25, const Color(0xFFF59E0B))),
        Positioned(top: 10, right: 0, child: _buildMiniGift(24, 20, const Color(0xFFEF4444))),
        Positioned(top: 8, right: 5, child: Icon(Icons.trending_up, color: _accent, size: 18)),
      ],
    );
  }

  Widget _buildMiniGift(double w, double h, Color color) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Center(child: Container(width: 2, height: h * 0.6, color: Colors.white.withValues(alpha: 0.7))),
    );
  }

  // ─── Shared widgets ───
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.18, color: color),
      ),
    );
  }

  Widget _buildAccentBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.18, color: Colors.white),
      ),
    );
  }

  Widget _buildCTA({required String label, required Color bg, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

class _FloatingCoin extends StatefulWidget {
  final double size, left, top, delay, duration;
  const _FloatingCoin({required Key key, required this.size, required this.left, required this.top, required this.delay, required this.duration}) : super(key: key);

  @override
  State<_FloatingCoin> createState() => _FloatingCoinState();
}

class _FloatingCoinState extends State<_FloatingCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _yAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.duration * 1000).toInt()));
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.8), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _yAnim = Tween<double>(begin: 10, end: -10).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
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
        return Positioned(
          left: 50 + widget.left,
          top: 50 + widget.top + _yAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0x80FFC800), blurRadius: 6)]),
              child: Image.asset(
                'assets/images/SuperCOin-removebg-preview.png',
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.circle, size: widget.size, color: const Color(0xFFFFC800)),
              ),
            ),
          ),
        );
      },
    );
  }
}
