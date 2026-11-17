import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/payment_result/payment_result_bloc.dart';
import 'package:gift360/bloc/payment_result/payment_result_event.dart';
import 'package:gift360/bloc/payment_result/payment_result_state.dart';
import 'package:gift360/features/payment/presentation/screens/payment_result_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class PaymentResultView extends StatelessWidget {
  const PaymentResultView({
    super.key,
    this.status,
    this.txnId,
    this.error,
    this.orderNumber,
  });

  final String? status;
  final String? txnId;
  final String? error;
  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<PaymentResultBloc, PaymentResultEvent, PaymentResultState>(
      create: PaymentResultBloc.new,
      started: const PaymentResultStarted(),
      maxContentWidth: 720,
      child: PaymentResultScreen(
        status: status,
        txnId: txnId,
        error: error,
        orderNumber: orderNumber,
      ),
    );
  }
}