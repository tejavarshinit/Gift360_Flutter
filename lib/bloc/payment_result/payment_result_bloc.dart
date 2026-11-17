import 'package:flutter_bloc/flutter_bloc.dart';

import 'payment_result_event.dart';
import 'payment_result_state.dart';

class PaymentResultBloc extends Bloc<PaymentResultEvent, PaymentResultState> {
  PaymentResultBloc() : super(const PaymentResultState()) {
    on<PaymentResultStarted>(_onStarted);
    on<PaymentResultRefreshed>(_onRefreshed);
  }

  void _onStarted(PaymentResultStarted event, Emitter<PaymentResultState> emit) {
    emit(state.copyWith(status: PaymentResultStatus.ready, message: ''));
  }

  void _onRefreshed(PaymentResultRefreshed event, Emitter<PaymentResultState> emit) {
    emit(state.copyWith(status: PaymentResultStatus.ready, message: ''));
  }
}