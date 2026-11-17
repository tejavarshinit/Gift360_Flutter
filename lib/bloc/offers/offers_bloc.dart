import 'package:flutter_bloc/flutter_bloc.dart';

import 'offers_event.dart';
import 'offers_state.dart';

class OffersBloc extends Bloc<OffersEvent, OffersState> {
  OffersBloc() : super(const OffersState()) {
    on<OffersStarted>(_onStarted);
    on<OffersRefreshed>(_onRefreshed);
  }

  void _onStarted(OffersStarted event, Emitter<OffersState> emit) {
    emit(state.copyWith(status: OffersStatus.ready, message: ''));
  }

  void _onRefreshed(OffersRefreshed event, Emitter<OffersState> emit) {
    emit(state.copyWith(status: OffersStatus.ready, message: ''));
  }
}