import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingRefreshed>(_onRefreshed);
  }

  void _onStarted(OnboardingStarted event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(status: OnboardingStatus.ready, message: ''));
  }

  void _onRefreshed(OnboardingRefreshed event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(status: OnboardingStatus.ready, message: ''));
  }
}