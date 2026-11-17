import 'package:flutter_bloc/flutter_bloc.dart';

import 'nearby_event.dart';
import 'nearby_state.dart';

class NearbyBloc extends Bloc<NearbyEvent, NearbyState> {
  NearbyBloc() : super(const NearbyState()) {
    on<NearbyStarted>(_onStarted);
    on<NearbyRefreshed>(_onRefreshed);
  }

  void _onStarted(NearbyStarted event, Emitter<NearbyState> emit) {
    emit(state.copyWith(status: NearbyStatus.ready, message: ''));
  }

  void _onRefreshed(NearbyRefreshed event, Emitter<NearbyState> emit) {
    emit(state.copyWith(status: NearbyStatus.ready, message: ''));
  }
}