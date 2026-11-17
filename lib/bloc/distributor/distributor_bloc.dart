import 'package:flutter_bloc/flutter_bloc.dart';

import 'distributor_event.dart';
import 'distributor_state.dart';

class DistributorBloc extends Bloc<DistributorEvent, DistributorState> {
  DistributorBloc() : super(const DistributorState()) {
    on<DistributorStarted>(_onStarted);
    on<DistributorRefreshed>(_onRefreshed);
  }

  void _onStarted(DistributorStarted event, Emitter<DistributorState> emit) {
    emit(state.copyWith(status: DistributorStatus.ready, message: ''));
  }

  void _onRefreshed(DistributorRefreshed event, Emitter<DistributorState> emit) {
    emit(state.copyWith(status: DistributorStatus.ready, message: ''));
  }
}