import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InstantGiftingCarousel extends StatefulWidget {
  final VoidCallback? onExploreBrands;
  final VoidCallback? onPartnerWithUs;
  final ValueChanged<String>? onBrandTap;

  const InstantGiftingCarousel({
    super.key,
    this.onExploreBrands,
    this.onPartnerWithUs,
    this.onBrandTap,
  });

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
  static const _autoInterval = Duration(seconds: 3);

  // Brand IDs for the SuperCoin nudge cards (match React InstantGiftingBanner).
  static const _uberBrandId = '3e4245c1-a17c-48e4-aa41-e8657d2886e4';
  static const _blinkitBrandId = 'a5fea1a3-3e17-414f-a953-407125080d77';
  static const _bataBrandId = '335f53f7-68f6-4eb0-be45-e571c1044cf9';

  // Soft peach → lavender gradient, matches the reference web banner.
  static const _cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF9F0), Color(0xFFF8F6FF), Color(0xFFF3F1FE)],
    stops: [0.0, 0.6, 1.0],
  );

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
      final next = (_currentPage + 1) % 4;
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
        final isMobile = constraints.maxWidth < 420;
        final padding = isMobile
            ? const EdgeInsets.fromLTRB(18, 18, 18, 18)
            : const EdgeInsets.fromLTRB(40, 30, 40, 30);
        // Sized so the tallest slide (step-flow) fits without overflow,
        // with a little breathing room for vertical centering.
        final cardHeight = isMobile ? 185.0 : 220.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onPanDown: (_) => _onUserInteract(),
              onPanEnd: (_) => _onUserRelease(),
              onTapDown: (_) => _onUserInteract(),
              onTapUp: (_) => _onUserRelease(),
              child: Container(
                height: cardHeight,
                decoration: BoxDecoration(
                  gradient: _cardGradient,
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
                      _buildAnimatedBrandNudge('assets/images/uber (2).png', 'Uber', 250, _uberBrandId),
                      _buildAnimatedBrandNudge('assets/images/blinkit.png', 'Blinkit', 150, _blinkitBrandId),
                      _buildAnimatedBrandNudge('assets/images/bataa.png', 'Bata', 150, _bataBrandId),
                      _buildSlide3(padding, isMobile),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildDots(),
          ],
        );
      },
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
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

  Widget _buildBrandNudge(String asset, String brand, String message, VoidCallback? onExplore) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        Container(color: Colors.white.withValues(alpha: 0.18)),
        Positioned(
          top: 35,
          left: 125,
          child: Row(
            children: ['Apply SC', 'Applied', '₹100 saved'].map((label) {
              return Container(
                margin: const EdgeInsets.only(right: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 7, height: 7),
                    const SizedBox(width: 2),
                    Text(label, style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w800, color: _accent)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 12,
          child: Container(
            width: 140,
            height: 126,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE9FE)),
              boxShadow: const [BoxShadow(color: Color(0x2E7C3AED), blurRadius: 20, offset: Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 12, height: 12),
                    const SizedBox(width: 3),
                    Text('150 SC available', style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 2),
                Row(children: [Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))), const SizedBox(width: 5), Text(brand, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700))]),
                const Spacer(),
                Text('₹500', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('₹500', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: _accent)),
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Toggle ON for demo', style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w600, color: _accent)), Container(width: 32, height: 18, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(20)), child: const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(2), child: CircleAvatar(radius: 7, backgroundColor: Colors.white))))]),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 13,
          child: Text('Try the toggle — see 20% off', style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w600, color: _accent)),
        ),
      ],
    );
  }

  Widget _buildAnimatedBrandNudge(String asset, String brand, int availableCoins, String brandId) {
    return _AnimatedBrandNudge(
      asset: asset,
      brand: brand,
      availableCoins: availableCoins,
      brandId: brandId,
      onBrandTap: widget.onBrandTap,
    );
  }

  // ─── Slide 1: Step Flow ───
  Widget _buildSlide1(EdgeInsets padding, bool isMobile) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAccentBadge('INSTANT GIFTING'),
          SizedBox(height: isMobile ? 3 : 5),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 14 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
                height: 1.2,
              ),
              children: const [
                TextSpan(text: 'Pick a brand, buy a voucher, '),
                TextSpan(text: 'send it', style: TextStyle(color: Color(0xFF7C3AED))),
                TextSpan(text: ' in seconds'),
              ],
            ),
            maxLines: 2,
          ),
          SizedBox(height: isMobile ? 6 : 10),
          _CtaButton(label: 'Start gifting', bg: _accent, onTap: widget.onExploreBrands, useGradient: true),
          SizedBox(height: isMobile ? 8 : 12),
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

    final circleSize = isMobile ? 34.0 : 44.0;
    final iconSize = isMobile ? 15.0 : 20.0;
    final titleSize = isMobile ? 10.0 : 13.0;
    final descSize = isMobile ? 8.0 : 11.0;
    final stepLabelSize = isMobile ? 7.0 : 10.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        final s = steps[i];
        return [
          if (i > 0)
            Padding(
              padding: EdgeInsets.only(top: circleSize / 2 - 1),
              child: Container(
                height: 2,
                width: 6,
                color: const Color(0xFFEDE9FE),
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
                  style: GoogleFonts.poppins(fontSize: stepLabelSize, letterSpacing: 0.5, color: Colors.grey[400]),
                ),
                const SizedBox(height: 1),
                Text(
                  s.$2,
                  style: GoogleFonts.poppins(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.grey[900]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 1),
                  Text(
                    s.$3,
                    style: GoogleFonts.poppins(fontSize: descSize, color: Colors.grey[500]),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: isMobile ? 1 : 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccentBadge('REWARDS'),
                SizedBox(height: isMobile ? 4 : 8),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 14 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                    children: const [
                      TextSpan(text: 'Earn '),
                      TextSpan(text: 'SuperCoins', style: TextStyle(color: Color(0xFF7C3AED))),
                      TextSpan(text: ' on every purchase'),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 3 : 6),
                Text(
                  'Get rewarded every time you buy or send a gift voucher.',
                  style: GoogleFonts.poppins(fontSize: isMobile ? 10 : 13, color: Colors.grey[500], height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 6 : 12),
                if (isMobile)
                  _CtaButton(label: 'Explore Now', bg: _accent, onTap: widget.onExploreBrands, useGradient: true)
                else
                  Row(
                    children: [
                      _CtaButton(label: 'Explore Now', bg: _accent, onTap: widget.onExploreBrands, useGradient: true),
                      const SizedBox(width: 14),
                      Expanded(child: _buildSuperCoinInfo()),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          SizedBox(
            width: isMobile ? 90 : 160,
            height: isMobile ? 90 : 160,
            child: _buildSuperCoinIllustration(small: isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperCoinInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: Color(0xFFF3F0FF), shape: BoxShape.circle),
          child: const Icon(Icons.monetization_on_outlined, color: _accent, size: 20),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SuperCoins', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[900])),
              Text(
                'Redeem across 500+ brands on Gift360',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuperCoinIllustration({bool small = false}) {
    final imgWidth = small ? 72.0 : 150.0;
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
          final left = -(small ? 26.0 : 42.0) + rng.nextDouble() * (small ? 52 : 84);
          final top = -(small ? 36.0 : 62.0) + rng.nextDouble() * (small ? 72 : 124);
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: isMobile ? 1 : 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccentBadge('PARTNER'),
                SizedBox(height: isMobile ? 4 : 8),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 14 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                    children: const [
                      TextSpan(text: 'Unlock '),
                      TextSpan(text: 'bulk pricing', style: TextStyle(color: Color(0xFF7C3AED))),
                      TextSpan(text: ' as a partner'),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 3 : 6),
                Text(
                  isMobile
                      ? 'Bulk pricing, smart reselling, and corporate gifting.'
                      : 'Bulk pricing, smart reselling, and corporate gifting — all in one place.',
                  style: GoogleFonts.poppins(fontSize: isMobile ? 10 : 13, color: Colors.grey[500], height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 6 : 12),
                _CtaButton(label: 'Partner With Us', bg: _accent, onTap: widget.onPartnerWithUs, useGradient: true),
                if (!isMobile) ...[
                  const SizedBox(height: 10),
                  _buildPartnerChips(),
                ],
              ],
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            child: Image.asset(
              'assets/images/coorp.png',
              width: isMobile ? 120 : 160,
              height: isMobile ? 120 : 160,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: isMobile ? 100 : 160,
                height: isMobile ? 100 : 160,
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(isMobile ? 10 : 12)),
                child: Icon(Icons.business, size: isMobile ? 40 : 64, color: Colors.white),
              ),
            ),
          ),
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
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Shared widgets ───
  Widget _buildAccentBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.18, color: Colors.white),
      ),
    );
  }
}

// ─── Pressable CTA — subtle scale-down on tap, mirrors the web's active:scale states ───
enum _DemoPhase { idle, waiting, ghostTap, toggling, on, off }

class _AnimatedBrandNudge extends StatefulWidget {
  final String asset;
  final String brand;
  final int availableCoins;
  final String brandId;
  final ValueChanged<String>? onBrandTap;

  const _AnimatedBrandNudge({
    required this.asset,
    required this.brand,
    required this.availableCoins,
    required this.brandId,
    this.onBrandTap,
  });

  @override
  State<_AnimatedBrandNudge> createState() => _AnimatedBrandNudgeState();
}

class _AnimatedBrandNudgeState extends State<_AnimatedBrandNudge> {
  Timer? _timer;
  _DemoPhase _phase = _DemoPhase.idle;
  bool _toggleOn = false;
  bool _userInteracted = false;
  int _playCount = 0;

  @override
  void initState() {
    super.initState();
    _schedule(const Duration(milliseconds: 3500), _showGhostTap);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration delay, VoidCallback action) {
    _timer?.cancel();
    if (_userInteracted || _playCount >= 3) return;
    _timer = Timer(delay, () {
      if (!mounted || _userInteracted) return;
      action();
    });
  }

  void _showGhostTap() {
    setState(() => _phase = _DemoPhase.ghostTap);
    _schedule(const Duration(milliseconds: 500), _turnOn);
  }

  void _turnOn() {
    setState(() {
      _phase = _DemoPhase.toggling;
      _toggleOn = true;
    });
    _schedule(const Duration(milliseconds: 1800), () {
      setState(() => _phase = _DemoPhase.on);
      _schedule(const Duration(milliseconds: 400), _turnOff);
    });
  }

  void _turnOff() {
    setState(() {
      _phase = _DemoPhase.off;
      _toggleOn = false;
    });
    _schedule(const Duration(milliseconds: 300), () {
      _playCount++;
      setState(() => _phase = _DemoPhase.idle);
      if (_playCount < 3) _schedule(const Duration(milliseconds: 3500), _showGhostTap);
    });
  }

  void _handleToggle() {
    _timer?.cancel();
    setState(() {
      _userInteracted = true;
      _phase = _DemoPhase.idle;
      _toggleOn = !_toggleOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAnimating = _phase == _DemoPhase.ghostTap || _phase == _DemoPhase.toggling;
    final priceColor = _toggleOn ? _accentColor : Colors.black87;
    final displayedCoins = _toggleOn && widget.brand == 'Uber' ? 150 : widget.availableCoins;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(widget.asset, fit: BoxFit.cover),
        Container(color: Colors.white.withValues(alpha: 0.18)),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => widget.onBrandTap?.call(widget.brandId),
          ),
        ),
        Positioned(
          top: 35,
          left: 125,
          child: Row(
            children: ['Apply SC', 'Applied', '\u20b9100 saved'].map((label) => Container(
              margin: const EdgeInsets.only(right: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 7, height: 7),
                const SizedBox(width: 2),
                Text(label, style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w800, color: _accentColor)),
              ]),
            )).toList(),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 12,
          child: GestureDetector(
            onTap: () => widget.onBrandTap?.call(widget.brandId),
            child: Container(
            width: 140,
            height: 126,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEDE9FE)), boxShadow: const [BoxShadow(color: Color(0x2E7C3AED), blurRadius: 20, offset: Offset(0, 6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Image.asset('assets/images/SuperCOin-removebg-preview.png', width: 12, height: 12),
                const SizedBox(width: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$displayedCoins SC available',
                    key: ValueKey(displayedCoins),
                    style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.grey[600]),
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: Center(child: Text(widget.brand == 'Uber' ? 'U' : 'G', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 5),
                Text(widget.brand, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _toggleOn
                    ? Row(
                        key: const ValueKey('discount-details'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Max 20% redeemable', style: GoogleFonts.poppins(fontSize: 6, fontWeight: FontWeight.w600, color: _accentColor)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFE9D5FF), borderRadius: BorderRadius.circular(8)),
                            child: Text('20% off', style: GoogleFonts.poppins(fontSize: 6, fontWeight: FontWeight.w800, color: _accentColor)),
                          ),
                        ],
                      )
                    : const SizedBox(key: ValueKey('no-discount-details'), height: 0),
              ),
              const SizedBox(height: 2),
              Text(
                '\u20b9500',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  decoration: _toggleOn ? TextDecoration.lineThrough : TextDecoration.none,
                  color: _toggleOn ? Colors.black45 : Colors.black87,
                ),
              ),
              SizedBox(
                height: 22,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _toggleOn ? '\u20b9400' : '\u20b9500',
                    key: ValueKey(_toggleOn),
                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: priceColor),
                  ),
                ),
              ),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_toggleOn ? 'SuperCoins applied' : 'Toggle ON for demo', style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w600, color: _accentColor)),
                GestureDetector(onTap: _handleToggle, child: AnimatedContainer(duration: const Duration(milliseconds: 300), width: 32, height: 18, padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: _toggleOn ? _accentColor : const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(20)), child: AnimatedAlign(duration: const Duration(milliseconds: 300), alignment: _toggleOn ? Alignment.centerRight : Alignment.centerLeft, child: const CircleAvatar(radius: 7, backgroundColor: Colors.white)))),
              ]),
            ]),
            ),
          ),
        ),
        if (_toggleOn && widget.onBrandTap != null)
          Positioned(
            right: 12,
            bottom: 13,
            child: GestureDetector(
              onTap: () => widget.onBrandTap?.call(widget.brandId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Color(0x667C3AED), blurRadius: 14, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Buy with SuperCoins',
                      style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Positioned(
            right: 12,
            bottom: 13,
            child: Text('Try the toggle - see 20% off', style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w600, color: _accentColor)),
          ),
        if (isAnimating) Positioned(left: 128, bottom: 21, child: IgnorePointer(child: AnimatedScale(scale: _phase == _DemoPhase.ghostTap ? 1 : 0.72, duration: const Duration(milliseconds: 300), child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.8), border: Border.all(color: _accentColor, width: 2)), child: const Icon(Icons.touch_app, size: 14, color: _accentColor))))),
      ],
    );
  }
}

const _accentColor = Color(0xFF7C3AED);

class _CtaButton extends StatefulWidget {
  final String label;
  final Color bg;
  final VoidCallback? onTap;
  final bool useGradient;
  const _CtaButton({required this.label, required this.bg, this.onTap, this.useGradient = false});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : (_hovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: widget.useGradient
                  ? LinearGradient(
                      colors: [widget.bg, widget.bg.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: widget.useGradient ? null : widget.bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (_hovered && !isDisabled)
                  BoxShadow(
                    color: widget.bg.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: widget.bg.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.white.withValues(alpha: 0.25),
                highlightColor: Colors.white.withValues(alpha: 0.1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: isDisabled ? 0.5 : 1.0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white.withValues(alpha: isDisabled ? 0.5 : 1.0),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
