import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding1_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding2_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding3_screen.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('g360_onboarding_v3', true);
    if (mounted) {
      context.go('/register');
    }
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        physics: const BouncingScrollPhysics(),
        children: [
          SplashScreen(
            onComplete: _nextPage,
            onSkip: _completeOnboarding,
          ),
          WelcomeScreen(
            onSkip: _completeOnboarding,
            onNext: _nextPage,
          ),
          Onboarding1Screen(
            onSkip: _completeOnboarding,
            onNext: _nextPage,
          ),
          Onboarding2Screen(
            onSkip: _completeOnboarding,
            onNext: _nextPage,
          ),
          Onboarding3Screen(
            onBack: _prevPage,
            onStart: _completeOnboarding,
          ),
        ],
      ),
    );
  }
}
