import 'package:flutter_bloc/flutter_bloc.dart';

import 'spin_wheel_event.dart';
import 'spin_wheel_state.dart';

class SpinWheelBloc extends Bloc<SpinWheelEvent, SpinWheelState> {
  SpinWheelBloc() : super(const SpinWheelState()) {
    on<SpinWheelStarted>(_onStarted);
    on<SpinWheelRefreshed>(_onRefreshed);
  }

  void _onStarted(SpinWheelStarted event, Emitter<SpinWheelState> emit) {
    emit(state.copyWith(status: SpinWheelStatus.ready, message: ''));
  }

  void _onRefreshed(SpinWheelRefreshed event, Emitter<SpinWheelState> emit) {
    emit(state.copyWith(status: SpinWheelStatus.ready, message: ''));
  }
}