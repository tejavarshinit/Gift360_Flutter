import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/bloc/onboarding1/onboarding1_bloc.dart';
import 'package:gift360/bloc/onboarding1/onboarding1_event.dart';
import 'package:gift360/bloc/onboarding1/onboarding1_state.dart';
import 'package:gift360/bloc/onboarding2/onboarding2_bloc.dart';
import 'package:gift360/bloc/onboarding2/onboarding2_event.dart';
import 'package:gift360/bloc/onboarding2/onboarding2_state.dart';
import 'package:gift360/bloc/onboarding3/onboarding3_bloc.dart';
import 'package:gift360/bloc/onboarding3/onboarding3_event.dart';
import 'package:gift360/bloc/onboarding3/onboarding3_state.dart';
import 'package:gift360/bloc/splash/splash_bloc.dart';
import 'package:gift360/bloc/splash/splash_event.dart';
import 'package:gift360/bloc/splash/splash_state.dart';
import 'package:gift360/bloc/welcome/welcome_bloc.dart';
import 'package:gift360/bloc/welcome/welcome_event.dart';
import 'package:gift360/bloc/welcome/welcome_state.dart';
import 'package:gift360/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding1_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding2_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding3_screen.dart';
import 'package:gift360/core/navigation/app_router.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
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
    await ref.read(onboardingCompleteProvider.notifier).complete();
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
          ConnectedPage<SplashBloc, SplashEvent, SplashState>(
            create: SplashBloc.new,
            started: const SplashStarted(),
            child: SplashScreen(
              onComplete: _nextPage,
              onSkip: _completeOnboarding,
            ),
          ),
          ConnectedPage<WelcomeBloc, WelcomeEvent, WelcomeState>(
            create: WelcomeBloc.new,
            started: const WelcomeStarted(),
            child: WelcomeScreen(
              onSkip: _completeOnboarding,
              onNext: _nextPage,
            ),
          ),
          ConnectedPage<Onboarding1Bloc, Onboarding1Event, Onboarding1State>(
            create: Onboarding1Bloc.new,
            started: const Onboarding1Started(),
            child: Onboarding1Screen(
              onSkip: _completeOnboarding,
              onNext: _nextPage,
            ),
          ),
          ConnectedPage<Onboarding2Bloc, Onboarding2Event, Onboarding2State>(
            create: Onboarding2Bloc.new,
            started: const Onboarding2Started(),
            child: Onboarding2Screen(
              onSkip: _completeOnboarding,
              onNext: _nextPage,
            ),
          ),
          ConnectedPage<Onboarding3Bloc, Onboarding3Event, Onboarding3State>(
            create: Onboarding3Bloc.new,
            started: const Onboarding3Started(),
            child: Onboarding3Screen(
              onBack: _prevPage,
              onStart: _completeOnboarding,
            ),
          ),
        ],
      ),
    );
  }
}
