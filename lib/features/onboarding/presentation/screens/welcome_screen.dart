import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';
import 'package:gift360/features/onboarding/presentation/widgets/navigation_bar.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const WelcomeScreen({super.key, required this.onSkip, required this.onNext});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoBlastController;
  late final AnimationController _logoBurstController;
  late final AnimationController _scaleInController;
  late final AnimationController _fadeUpController;

  @override
  void initState() {
    super.initState();
    _logoBlastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoBlastController.forward();
    _logoBurstController.forward();
    _scaleInController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeUpController.forward();
    });
  }

  @override
  void dispose() {
    _logoBlastController.dispose();
    _logoBurstController.dispose();
    _scaleInController.dispose();
    _fadeUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.4),
            radius: 1.2,
            colors: [
              Color(0xFFDBB898),
              Color(0xFFF0E4DE),
              Colors.white,
            ],
            stops: [0.0, 0.35, 0.75],
          ),
        ),
        child: Stack(
          children: [

            // Top-left blur
            Positioned(
              top: -40,
              left: MediaQuery.of(context).size.width / 2 - 104,
              child: Container(
                width: 208,
                height: 208,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x6BFFBE78),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.72],
                  ),
                ),
              ),
            ),

            // Right blur
            Positioned(
              top: 160,
              right: -20,
              child: Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x3D7D6EF2),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.72],
                  ),
                ),
              ),
            ),

            // Center content
            Center(
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
                        scale = 0.2 + (t / 0.4) * (1.1 - 0.2);
                        opacity = (t / 0.4);
                      } else {
                        scale = 1.1 + ((t - 0.4) / 0.6) * (1.8 - 1.1);
                        opacity = 1 - ((t - 0.4) / 0.6);
                      }
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xF2FFFFFF),
                                  Color(0xB8FFE0C2),
                                  Color(0x00FFFFFF),
                                ],
                                stops: [0.0, 0.40, 0.74],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Logo with burst animation
                  AnimatedBuilder(
                    animation: _logoBurstController,
                    builder: (context, child) {
                      final t = _logoBurstController.value;
                      double scale;
                      double opacity;
                      if (t < 0.45) {
                        scale = 0.35 + (t / 0.45) * (1.16 - 0.35);
                        opacity = (t / 0.45);
                      } else if (t < 0.7) {
                        scale = 1.16 - ((t - 0.45) / 0.25) * (1.16 - 0.96);
                        opacity = 1;
                      } else {
                        scale = 0.96 + ((t - 0.7) / 0.3) * (1 - 0.96);
                        opacity = 1;
                      }
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Image.asset(
                            'assets/images/Gift.png',
                            width: 96,
                            height: 96,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 96,
                                height: 96,
                                decoration: const BoxDecoration(
                                  color: OnboardingDesign.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.card_giftcard,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Wordmark with scale-in animation
                  AnimatedBuilder(
                    animation: _scaleInController,
                    builder: (context, child) {
                      final t = _scaleInController.value;
                      final scale = 0.85 + t * 0.15;
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: t,
                          child: Image.asset(
                            'assets/images/G word.png',
                            width: 288,
                            height: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                'Gift360',
                                style: OnboardingDesign.poppins(
                                  fontSize: 36,
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

                  const SizedBox(height: 12),

                  // Title
                  AnimatedBuilder(
                    animation: _fadeUpController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 16 * (1 - _fadeUpController.value)),
                        child: Opacity(
                          opacity: _fadeUpController.value,
                          child: Text(
                            'Gift Smatter, Choose Freely',
                            style: OnboardingDesign.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: OnboardingDesign.foreground,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                ],
              ),
            ),

            // Bottom navigation
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
                    OnboardingNavBar(
                      onSkip: widget.onSkip,
                      onNext: widget.onNext,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
