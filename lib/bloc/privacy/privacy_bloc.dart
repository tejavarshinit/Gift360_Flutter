import 'package:flutter_bloc/flutter_bloc.dart';

import 'privacy_event.dart';
import 'privacy_state.dart';

class PrivacyBloc extends Bloc<PrivacyEvent, PrivacyState> {
  PrivacyBloc() : super(const PrivacyState()) {
    on<PrivacyStarted>(_onStarted);
    on<PrivacyRefreshed>(_onRefreshed);
  }

  void _onStarted(PrivacyStarted event, Emitter<PrivacyState> emit) {
    emit(state.copyWith(status: PrivacyStatus.ready, message: ''));
  }

  void _onRefreshed(PrivacyRefreshed event, Emitter<PrivacyState> emit) {
    emit(state.copyWith(status: PrivacyStatus.ready, message: ''));
  }
}