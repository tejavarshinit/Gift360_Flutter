import 'package:flutter_bloc/flutter_bloc.dart';

import 'corporate_event.dart';
import 'corporate_state.dart';

class CorporateBloc extends Bloc<CorporateEvent, CorporateState> {
  CorporateBloc() : super(const CorporateState()) {
    on<CorporateStarted>(_onStarted);
    on<CorporateRefreshed>(_onRefreshed);
  }

  void _onStarted(CorporateStarted event, Emitter<CorporateState> emit) {
    emit(state.copyWith(status: CorporateStatus.ready, message: ''));
  }

  void _onRefreshed(CorporateRefreshed event, Emitter<CorporateState> emit) {
    emit(state.copyWith(status: CorporateStatus.ready, message: ''));
  }
}