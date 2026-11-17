import 'package:flutter_bloc/flutter_bloc.dart';

import 'reseller_event.dart';
import 'reseller_state.dart';

class ResellerBloc extends Bloc<ResellerEvent, ResellerState> {
  ResellerBloc() : super(const ResellerState()) {
    on<ResellerStarted>(_onStarted);
    on<ResellerRefreshed>(_onRefreshed);
  }

  void _onStarted(ResellerStarted event, Emitter<ResellerState> emit) {
    emit(state.copyWith(status: ResellerStatus.ready, message: ''));
  }

  void _onRefreshed(ResellerRefreshed event, Emitter<ResellerState> emit) {
    emit(state.copyWith(status: ResellerStatus.ready, message: ''));
  }
}