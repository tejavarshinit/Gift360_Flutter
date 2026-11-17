import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding2_event.dart';
import 'onboarding2_state.dart';

class Onboarding2Bloc extends Bloc<Onboarding2Event, Onboarding2State> {
  Onboarding2Bloc() : super(const Onboarding2State()) {
    on<Onboarding2Started>(_onStarted);
    on<Onboarding2Refreshed>(_onRefreshed);
  }

  void _onStarted(Onboarding2Started event, Emitter<Onboarding2State> emit) {
    emit(state.copyWith(status: Onboarding2Status.ready, message: ''));
  }

  void _onRefreshed(Onboarding2Refreshed event, Emitter<Onboarding2State> emit) {
    emit(state.copyWith(status: Onboarding2Status.ready, message: ''));
  }
}