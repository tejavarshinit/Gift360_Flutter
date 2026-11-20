import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/festival/data/models/festival_config.dart';
import 'package:gift360/features/festival/presentation/providers/festival_provider.dart';
import 'package:gift360/features/festival/presentation/widgets/festival_image.dart';

class DiwaliAuthShell extends ConsumerStatefulWidget {
  final Widget child;
  final Widget switchPrompt;
  final Widget? afterMarquee;

  const DiwaliAuthShell({
    super.key,
    required this.child,
    required this.switchPrompt,
    this.afterMarquee,
  });

  @override
  ConsumerState<DiwaliAuthShell> createState() => _DiwaliAuthShellState();
}

class _DiwaliAuthShellState extends ConsumerState<DiwaliAuthShell>
    with TickerProviderStateMixin {
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);
  late final AnimationController _marqueeController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  static const _logos = [
    'assets/images/amazon.png',
    'assets/images/flipkart.png',
    'assets/images/myntra.png',
    'assets/images/nike.png',
    'assets/images/puma.png',
    'assets/images/bata.png',
    'assets/images/levis.png',
    'assets/images/tatacliq.png',
    'assets/images/ajio.png',
    'assets/images/zomato.png',
  ];

  @override
  void dispose() {
    _floatController.dispose();
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final festival = festivalConfigOf(ref);
    final theme = GoogleFonts.poppins();
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: FestivalImage(
                source: festival.loginBackgroundUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Column(
                      children: [
                        _buildHeader(festival),
                        const SizedBox(height: 8),
                        Text(
                          festival.headline,
                          textAlign: TextAlign.center,
                          style: theme.copyWith(
                            fontSize: 28,
                            height: .95,
                            fontWeight: FontWeight.w800,
                            color: festival.primaryColor,
                          ),
                        ),
                        Text(
                          festival.subheadline,
                          textAlign: TextAlign.center,
                          style: theme.copyWith(
                            fontSize: 22,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            color: festival.secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          festival.tagline,
                          style: theme.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: festival.accentColor.withValues(alpha: 0.8),
                          ),
                        ),
                        SizedBox(
                          height: 120,
                          child: AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                0,
                                -6 *
                                    Curves.easeInOut.transform(
                                      _floatController.value,
                                    ),
                              ),
                              child: child,
                            ),
                            child: FestivalImage(
                              source: festival.heroImageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        _buildStats(theme, festival),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E0D8)),
                            boxShadow: [
                              BoxShadow(
                                color: festival.accentColor.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: theme.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: festival.accentColor,
                                    ),
                                  ),
                                  if (festival.isActive &&
                                      festival.name.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: festival.primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 12,
                                            color: festival.primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            festival.name,
                                            style: theme.copyWith(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: festival.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              widget.child,
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 13,
                                    color: festival.secondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "we'll send a secure OTP to verify your number",
                                    style: theme.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF4E4E4E),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x4D8F6A10)),
                          ),
                          child: Center(child: widget.switchPrompt),
                        ),
                        const SizedBox(height: 8),
                        _buildTrustedBy(theme, festival),
                        if (widget.afterMarquee != null) ...[
                          const SizedBox(height: 4),
                          widget.afterMarquee!,
                        ],
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.go('/terms'),
                          child: Text(
                            'By continuing, you agree to our Terms & Conditions and Privacy Policy',
                            textAlign: TextAlign.center,
                            style: theme.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF4E4E4E),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FestivalConfig festival) {
    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 300,
            height: 110,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xF2FFFCEF), Color(0x00FFF8E1)],
              ),
            ),
          ),
          FestivalLogo(
            source: festival.logoUrl,
            maxHeight: 64,
            maxWidth: 240,
          ),
          if (festival.isActive && festival.badgeLabel.isNotEmpty)
            Positioned(
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: festival.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  festival.badgeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: festival.accentColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStats(TextStyle theme, FestivalConfig festival) {
    final stats = [
      ('25K+', 'Bought & Gifted', festival.primaryColor),
      ('20%', 'Upto Cashback', festival.secondaryColor),
      ('400+', 'Brands', festival.accentColor),
    ];
    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: .05),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      stat.$1,
                      style: theme.copyWith(
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: stat.$3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat.$2,
                      style: theme.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTrustedBy(TextStyle theme, FestivalConfig festival) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x408F6A10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFC9C9C9))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'TRUSTED BY 400+ BRANDS',
                  style: theme.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .5,
                    color: festival.accentColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFC9C9C9))),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 46,
                maxHeight: 46,
                child: AnimatedBuilder(
                  animation: _marqueeController,
                  builder: (context, child) => FractionalTranslation(
                    translation: Offset(-_marqueeController.value, 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [..._logos, ..._logos]
                        .map(
                          (asset) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Image.asset(
                              asset,
                              height: 40,
                              fit: BoxFit.contain,
                              opacity: const AlwaysStoppedAnimation(.8),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
