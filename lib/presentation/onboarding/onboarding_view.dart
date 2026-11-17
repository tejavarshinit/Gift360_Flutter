import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/onboarding/onboarding_bloc.dart';
import 'package:gift360/bloc/onboarding/onboarding_event.dart';
import 'package:gift360/bloc/onboarding/onboarding_state.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<OnboardingBloc, OnboardingEvent, OnboardingState>(
      create: OnboardingBloc.new,
      started: const OnboardingStarted(),
      
      child: const OnboardingPage(),
    );
  }
}