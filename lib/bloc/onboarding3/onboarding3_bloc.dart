import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding3_event.dart';
import 'onboarding3_state.dart';

class Onboarding3Bloc extends Bloc<Onboarding3Event, Onboarding3State> {
  Onboarding3Bloc() : super(const Onboarding3State()) {
    on<Onboarding3Started>(_onStarted);
    on<Onboarding3Refreshed>(_onRefreshed);
  }

  void _onStarted(Onboarding3Started event, Emitter<Onboarding3State> emit) {
    emit(state.copyWith(status: Onboarding3Status.ready, message: ''));
  }

  void _onRefreshed(Onboarding3Refreshed event, Emitter<Onboarding3State> emit) {
    emit(state.copyWith(status: Onboarding3Status.ready, message: ''));
  }
}