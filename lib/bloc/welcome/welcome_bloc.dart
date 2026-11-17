import 'package:flutter_bloc/flutter_bloc.dart';

import 'welcome_event.dart';
import 'welcome_state.dart';

class WelcomeBloc extends Bloc<WelcomeEvent, WelcomeState> {
  WelcomeBloc() : super(const WelcomeState()) {
    on<WelcomeStarted>(_onStarted);
    on<WelcomeRefreshed>(_onRefreshed);
  }

  void _onStarted(WelcomeStarted event, Emitter<WelcomeState> emit) {
    emit(state.copyWith(status: WelcomeStatus.ready, message: ''));
  }

  void _onRefreshed(WelcomeRefreshed event, Emitter<WelcomeState> emit) {
    emit(state.copyWith(status: WelcomeStatus.ready, message: ''));
  }
}