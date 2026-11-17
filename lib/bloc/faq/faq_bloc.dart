import 'package:flutter_bloc/flutter_bloc.dart';

import 'faq_event.dart';
import 'faq_state.dart';

class FaqBloc extends Bloc<FaqEvent, FaqState> {
  FaqBloc() : super(const FaqState()) {
    on<FaqStarted>(_onStarted);
    on<FaqRefreshed>(_onRefreshed);
  }

  void _onStarted(FaqStarted event, Emitter<FaqState> emit) {
    emit(state.copyWith(status: FaqStatus.ready, message: ''));
  }

  void _onRefreshed(FaqRefreshed event, Emitter<FaqState> emit) {
    emit(state.copyWith(status: FaqStatus.ready, message: ''));
  }
}