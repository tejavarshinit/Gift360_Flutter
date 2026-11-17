import 'package:flutter_bloc/flutter_bloc.dart';

import 'payment_webview_event.dart';
import 'payment_webview_state.dart';

class PaymentWebviewBloc extends Bloc<PaymentWebviewEvent, PaymentWebviewState> {
  PaymentWebviewBloc() : super(const PaymentWebviewState()) {
    on<PaymentWebviewStarted>(_onStarted);
    on<PaymentWebviewRefreshed>(_onRefreshed);
  }

  void _onStarted(PaymentWebviewStarted event, Emitter<PaymentWebviewState> emit) {
    emit(state.copyWith(status: PaymentWebviewStatus.ready, message: ''));
  }

  void _onRefreshed(PaymentWebviewRefreshed event, Emitter<PaymentWebviewState> emit) {
    emit(state.copyWith(status: PaymentWebviewStatus.ready, message: ''));
  }
}