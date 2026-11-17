import 'package:flutter_bloc/flutter_bloc.dart';

import 'terms_event.dart';
import 'terms_state.dart';

class TermsBloc extends Bloc<TermsEvent, TermsState> {
  TermsBloc() : super(const TermsState()) {
    on<TermsStarted>(_onStarted);
    on<TermsRefreshed>(_onRefreshed);
  }

  void _onStarted(TermsStarted event, Emitter<TermsState> emit) {
    emit(state.copyWith(status: TermsStatus.ready, message: ''));
  }

  void _onRefreshed(TermsRefreshed event, Emitter<TermsState> emit) {
    emit(state.copyWith(status: TermsStatus.ready, message: ''));
  }
}