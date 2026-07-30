import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';
import 'package:gift360/features/onboarding/presentation/widgets/page_indicator.dart';
import 'package:gift360/features/onboarding/presentation/widgets/navigation_bar.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const SplashScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoBlastController;
  late final AnimationController _logoBurstController;
  late final AnimationController _fadeUpController;
  late final AnimationController _dissolveController;
  late final List<AnimationController> _columnControllers;
  Timer? _autoAdvanceTimer;

  static const int _brandCount = 14;
  static const List<int> _columnOffsets = [0, 4, 8, 1, 6];

  @override
  void initState() {
    super.initState();
    _logoBlastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _fadeUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dissolveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _columnControllers = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      )..repeat();
    });

    _logoBlastController.forward();
    _logoBurstController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeUpController.forward();
    });
    _dissolveController.forward();

    _autoAdvanceTimer = Timer(const Duration(milliseconds: 3600), () {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _logoBlastController.dispose();
    _logoBurstController.dispose();
    _fadeUpController.dispose();
    _dissolveController.dispose();
    for (final c in _columnControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _getColumnAssets(int offset) {
    final items = <String>[];
    for (int i = 0; i < 12; i++) {
      items.add(OnboardingDesign.brandNames[(offset + i) % _brandCount]);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          // Scrolling brand columns
          ...List.generate(5, (colIndex) {
            final assets = _getColumnAssets(_columnOffsets[colIndex]);
            final isEven = colIndex % 2 == 0;
            final screenH = MediaQuery.of(context).size.height;
            return Positioned(
              top: 40,
              left: 8 + (colIndex * (MediaQuery.of(context).size.width - 16) / 5),
              width: (MediaQuery.of(context).size.width - 16 - 16) / 5,
              height: screenH - 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _columnControllers[colIndex],
                    builder: (context, child) {
                      final progress = _columnControllers[colIndex].value;
                      final offset = isEven
                          ? -progress * 1200
                          : progress * 1200;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Transform.translate(
                            offset: Offset(0, offset),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...assets,
                                ...assets,
                              ].map((brand) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: OnboardingDesign.shadowTile,
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: Image.asset(
                                        'assets/images/pp-brands/$brand.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              brand.toUpperCase(),
                                              style: OnboardingDesign.poppins(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w700,
                                                color: OnboardingDesign.foreground,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          }),

          // Center logo section
          Positioned(
            top: MediaQuery.of(context).size.height * 0.26,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo blast gradient
                  AnimatedBuilder(
                    animation: _logoBlastController,
                    builder: (context, child) {
                      final t = _logoBlastController.value;
                      double scale;
                      double opacity;
                      if (t < 0.4) {
                        scale = 0.24 + (t / 0.4) * (1.12 - 0.24);
                        opacity = (t / 0.4);
                      } else {
                        scale = 1.12 + ((t - 0.4) / 0.6) * (1.9 - 1.12);
                        opacity = 1 - ((t - 0.4) / 0.6);
                      }
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Container(
                            width: 144,
                            height: 144,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFAFFFFFF),
                                  Color(0xD1FFE5C2),
                                  Color(0x00FFFFFF),
                                ],
                                stops: [0.0, 0.42, 0.76],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Logo container with burst animation
                  AnimatedBuilder(
                    animation: _logoBurstController,
                    builder: (context, child) {
                      final t = _logoBurstController.value;
                      double scale;
                      double opacity;
                      if (t < 0.42) {
                        scale = 0.3 + (t / 0.42) * (1.14 - 0.3);
                        opacity = (t / 0.42);
                      } else if (t < 0.72) {
                        scale = 1.14 - ((t - 0.42) / 0.3) * (1.14 - 0.97);
                        opacity = 1;
                      } else {
                        scale = 0.97 + ((t - 0.72) / 0.28) * (1 - 0.97);
                        opacity = 1;
                      }
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              boxShadow: OnboardingDesign.shadowCardSoft,
                            ),
                            child: Image.asset(
                              'assets/images/Gift.png',
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: OnboardingDesign.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.card_giftcard,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Wordmark
                  AnimatedBuilder(
                    animation: _fadeUpController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 16 * (1 - _fadeUpController.value)),
                        child: Opacity(
                          opacity: _fadeUpController.value,
                          child: Image.asset(
                            'assets/images/G word.png',
                            width: 208,
                            height: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                'Gift360',
                                style: OnboardingDesign.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: OnboardingDesign.foreground,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  AnimatedBuilder(
                    animation: _fadeUpController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 16 * (1 - _fadeUpController.value)),
                        child: Opacity(
                          opacity: _fadeUpController.value,
                          child: Text(
                            'Swipe left or tap next to continue',
                            style: OnboardingDesign.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: OnboardingDesign.foreground
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom gradient + navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xEBFFFFFF),
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                children: [
                  const PageIndicator(pageCount: 4, activeIndex: 0),
                  const SizedBox(height: 16),
                  OnboardingNavBar(
                    onSkip: widget.onSkip,
                    onNext: widget.onComplete,
                  ),
                ],
              ),
            ),
          ),

          // Dissolve overlay
          AnimatedBuilder(
            animation: _dissolveController,
            builder: (context, child) {
              final t = _dissolveController.value;
              final opacity = t < 0.72 ? 0.0 : ((t - 0.72) / 0.28);
              return IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
