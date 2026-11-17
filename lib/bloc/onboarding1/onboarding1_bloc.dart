import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding1_event.dart';
import 'onboarding1_state.dart';

class Onboarding1Bloc extends Bloc<Onboarding1Event, Onboarding1State> {
  Onboarding1Bloc() : super(const Onboarding1State()) {
    on<Onboarding1Started>(_onStarted);
    on<Onboarding1Refreshed>(_onRefreshed);
  }

  void _onStarted(Onboarding1Started event, Emitter<Onboarding1State> emit) {
    emit(state.copyWith(status: Onboarding1Status.ready, message: ''));
  }

  void _onRefreshed(Onboarding1Refreshed event, Emitter<Onboarding1State> emit) {
    emit(state.copyWith(status: Onboarding1Status.ready, message: ''));
  }
}