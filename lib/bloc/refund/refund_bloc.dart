import 'package:flutter_bloc/flutter_bloc.dart';

import 'refund_event.dart';
import 'refund_state.dart';

class RefundBloc extends Bloc<RefundEvent, RefundState> {
  RefundBloc() : super(const RefundState()) {
    on<RefundStarted>(_onStarted);
    on<RefundRefreshed>(_onRefreshed);
  }

  void _onStarted(RefundStarted event, Emitter<RefundState> emit) {
    emit(state.copyWith(status: RefundStatus.ready, message: ''));
  }

  void _onRefreshed(RefundRefreshed event, Emitter<RefundState> emit) {
    emit(state.copyWith(status: RefundStatus.ready, message: ''));
  }
}