import 'package:flutter_bloc/flutter_bloc.dart';

import 'splash_event.dart';
import 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc() : super(const SplashState()) {
    on<SplashStarted>(_onStarted);
    on<SplashRefreshed>(_onRefreshed);
  }

  void _onStarted(SplashStarted event, Emitter<SplashState> emit) {
    emit(state.copyWith(status: SplashStatus.ready, message: ''));
  }

  void _onRefreshed(SplashRefreshed event, Emitter<SplashState> emit) {
    emit(state.copyWith(status: SplashStatus.ready, message: ''));
  }
}